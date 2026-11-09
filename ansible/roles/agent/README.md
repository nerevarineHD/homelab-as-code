# CT111: Claude Code agent

This role retains the existing non-sudo claude user, Claude managed settings and
guard, read-only deploy key and homelab clone. Its LXC and firewall configuration
in tofu/agent.tf are unchanged.

The Codex trial was removed because bubblewrap could not create namespaces under
the existing LXC restrictions. retire-codex.yml removes only the trial binary,
version/cache/config directories, /home/claude/.codex and bubblewrap. It refuses
cleanup if a Codex auth.json exists, so unexpected credentials can be reviewed.
No other packages are autoremoved. Claude files and SSH keys are preserved.

Run the usual check/diff limited to agent before applying cleanup. An immediate
repeat run must report changed=0. New Codex provisioning lives in roles/codex
and tofu/codex.tf; see docs/codex-vm-migration.md.
