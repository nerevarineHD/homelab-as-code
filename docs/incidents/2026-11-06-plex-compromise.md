# Postmortem: Plex container (CT 101) cryptominer compromise

**Date of discovery:** 2026-11-06
**Status:** Contained. CT 101 stopped and isolated; rebuild/retire decision pending.
**Severity:** Medium. One container was compromised as an unprivileged service user. No root, no lateral movement, no data loss.

## Summary

Plex Media Server 1.42.2 in CT 101 was exposed to the internet via a manual port forward (WAN:32400 → 192.168.0.12) and was exploited through the Plex2Shell vulnerability chain. At least two separate cryptomining crews gained code execution as the `plex` user and ran XMRig miners for about 12 days (~Oct 24–25 to Nov 6), consuming 50–100% of the container's 4 CPU cores. The compromise was discovered during a routine CVE review, contained the same day, and confirmed limited to the `plex` user inside CT 101.

## Impact

- ~12 days of CPU theft (cryptomining) on 4 cores of the Proxmox host.
- Plex server token exposed (password reset and all sessions revoked).
- **Not impacted:** host, other containers, media library (bind mount was read-only), home network. No meaningful outbound proxy traffic observed.

## Root cause

1. **Vulnerable software.** Plex Media Server 1.42.2.10156 was affected by the Plex2Shell chain (CVE-2026-96652, -96654, -96655, -96656), which gives unauthenticated RCE, has a public PoC, and has been exploited in the wild since mid-October 2026. Fixed in 1.43.3.10861.
2. **Updates silently stopped.** Plex moved its apt repo from `downloads.plex.tv/repo/deb` to `repo.plex.tv/deb` starting with 1.43.0. The old repo now returns 404, so `apt` never offered the fix.
3. **Direct internet exposure from the main LAN, by design.** A port forward sent 32400 straight to 192.168.0.12 on the Default LAN, bypassing the DMZ that the other public services (Caddy, Valheim) use. This was a documented exception: the architecture README listed "Plex's own port" as the one LAN port reachable from outside. The one exception to the DMZ rule is the one that got exploited.

### Contributing factors

- CT 101 was a **privileged** LXC. The attackers never got root, but if they had, the step to the host would have been short.
- No alerting on sustained container CPU, so the miner ran unnoticed for 12 days.
- No remote syslog for gateway logs.
- Router IPS was on (Detect and Prevent, Medium, 8 of 12 threat categories) and never saw the Plex2Shell chain. Its log for Oct 20 – Nov 6 holds 85 events: 78 DShield blocklist drops (background scanner noise, a steady 2–9 a day with no change around the Oct 24–25 compromise) and 7 Tor node matches. Not one exploit signature, and nothing for the miner's outbound pool traffic on plain TCP :3333 / :10002. Signature IPS is not a substitute for patching or for keeping services off the internet.

## Timeline (local time)

| When | What |
|---|---|
| ~Oct 24–25 | CT 101 CPU jumps from ~0% to a 55–100% plateau, and memory rises to ~2.5 GiB (RandomX). Earliest artifact: `/var/lib/plexmediaserver/.wget-hsts`, Oct 25 21:14. |
| Oct 25 – Nov 6 | Automated exploit repeatedly drops `.so` payloads into Plex's Codecs dir, then fetches and runs `http://91.188.254.62/systemd`. Two crews fight over the box (rival-killing launcher, `pd.sh` → /dev/null blocks). |
| Oct 31 | Power event takes the lab down. Miner returns at boot via `@reboot` crontab entries. |
| Nov 6, 08:47 | CVE review of the home lab begins. |
| Nov 6, 11:16 | Plex upgraded 1.42.2 → 1.43.5.11079 via direct .deb (dead repo found). Vulnerability closed; existing foothold persists. |
| Nov 6, 11:23 | IOCs found in /tmp, /var/tmp and /dev/shm (fake `ksoftirqd`, `.migration118` loop, miner configs). |
| Nov 6, 11:25 | CT 101 network cut (`link_down=1`), evidence vzdump taken, container stopped, `onboot: 0`. |
| Nov 6, 11:28 | Offline analysis: persistence only in the `plex` crontab; no root, no system-level changes. |
| Nov 6, ~11:45 | Omada: `block-miner-c2` gateway ACL created; 32400 port forward deleted; UPnP confirmed already off. |
| Nov 6, 12:00 | Lateral-movement checks clean (host SSH/API logs, all container journals). |
| Nov 6, 12:10 | Proxmox RRD graphs confirm start date and show no sustained egress (proxy unlikely). |
| Nov 6, ~12:40 | Plex password reset, all sessions revoked; additional IOC IPs added to block list. |

## Detection

Found during a manual CVE review, not by monitoring. A simple "container CPU > 50% for 30 min" alert from the existing pve-exporter/Prometheus stack would have caught it within the first hour.

## Evidence

- vzdump: `/var/lib/vz/dump/vzdump-lxc-101-2026_11_06-11_25_22.tar.zst` (rootfs at time of containment)
- Notes and configs: `/root/ir-ct101/` on the Proxmox host

## Indicators of compromise

**Network (blocked at ER707 via `miner-c2` group):**

| IOC | Role |
|---|---|
| 91.188.254.62 | Dropper host (`/systemd` payload) |
| 80.87.206.91 | Crew A downloader + pool (:3333) |
| 85.137.54.178 | Crew A pool (:3333) |
| 176.123.7.7 | Crew A debug/telemetry endpoint |
| 130.94.112.118 | Crew B pool (:10002) |
| 89.125.187.0/24 | Crew B infrastructure |
| 192.42.116.15, 192.42.116.20 | Tor relays seen talking to CT 101 on Nov 3, 11:27:40–11:27:50 (IPS Tor signature, 4 events) |

**Host artifacts (in CT 101):**

- `/tmp/ksoftirqd`, `/var/tmp/ksoftirqd`: XMRig masquerading as a kernel thread
- `/var/tmp/.migration118` + `.loop` / `.beat` / `.tag`: persistence loop
- `/var/lib/plexmediaserver/{PlexScriptHost, Plex Tuner Service}`: implant copies (401,071 bytes)
- `/var/lib/plexmediaserver/Plex DLNA Server`: launcher script (rival killer, crontab scrubber)
- `.mine`, `.mstat`, `.pxcfg_*.b64`, `.boat.lock`, `.kpx.lck`: miner state and configs
- `pd.sh` / `plex_deploy.sh` symlinks → /dev/null in /tmp, /var/tmp and /dev/shm
- `zzNNNNN.so` files dropped into `.../Plex Media Server/Codecs/*/`
- `plex` user crontab entries running the above every 1–3 minutes and at `@reboot`

**Miner wallets (Monero):** `8A3vMrBU…` (crew A), `8AB1pyof…` (crew B)

## What went well

- Media bind mount was read-only, so the library couldn't be tampered with.
- The 4-core limit on CT 101 kept the miner from taking the whole host.
- Other public services were already in the DMZ.
- Containment preserved evidence (network cut first, snapshot backup before stop).

## Action items

- [x] Upgrade Plex past the Plex2Shell fix
- [x] Isolate and stop CT 101; preserve evidence
- [x] Delete WAN:32400 port forward; confirm UPnP off
- [x] Block IOC IPs at the gateway
- [x] Reset Plex password; revoke all sessions
- [x] Lateral-movement checks
- [x] Stop managing CT 101 in OpenTofu (`removed` block, `destroy = false`). The provider doesn't read `link_down`, so an apply would have restarted the container with no guarantee its network stayed cut
- [ ] Decide Plex's fate: retire, or rebuild as an **unprivileged** LXC, LAN-only, Remote Access off, own VLAN
- [ ] Alert on sustained container CPU (Prometheus/Grafana via pve-exporter)
- [ ] Remote syslog for Omada gateway + ACL/IDS logging
- [x] Review ER707 Threat Management for Oct 20 – Nov 6: no exploit or mining signatures fired
- [x] Check the 7 Tor events. Oct 30: Tor relay ↔ 192.168.0.124 (the admin desktop; a Brave private-with-Tor window, benign). Nov 3 17:58: Tor relay → Caddy on the DMZ (inbound scan, normal). **Nov 3 11:27: Tor relays 192.42.116.15 and 192.42.116.20 ↔ 192.168.0.12**, so at least one actor reached the Plex box through Tor during the compromise.
- [ ] Enable the remaining IPS categories (likely including mining/policy) and measure the throughput hit
- [ ] Update the public README: remove the 32400 → Plex path and the "Plex's own port" exception
- [ ] Disable SSH password auth on the host and all containers (Ansible)
- [ ] Audit all third-party apt repos for dead or moved sources (`apt update` errors should alert, not scroll by)
- [ ] Policy: anything internet-facing lives in the DMZ, no exceptions
