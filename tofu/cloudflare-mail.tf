# Mail for example.org (Oct 22).
#   Receiving: Cloudflare Email Routing -> Gmail. Its MX x3, the apex SPF and the cf2024-1 DKIM key
#              are created and locked by Email Routing itself, so they are NOT defined here
#              (same idea as the ddns-owned A records). Forwarding rules live in the dashboard.
#   Sending:   Gmail "Send mail as" through Resend's SMTP. Resend signs as example.org (DKIM)
#              and uses send.example.org as the bounce domain, so the apex SPF stays untouched.

resource "cloudflare_dns_record" "family_resend_dkim" {
  zone_id = local.zones["family"]
  name    = "resend._domainkey.example.org"
  type    = "TXT"
  content = "\"p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQC5TPBAym1+O2ZnV5hEzCrJN2LO9ZmRG405o8wyZaNq+NXososoWNbd47YrpkdcVmxIQrsODp4U3emjDBl08Z1FGeLxq4qomnf2vGMaN82R79KJYRIPmPBjsYR62BGLW3E3yQWUB80j2m8n3sZqSs6VdLfr/CARjCn17y3JdvVMGwIDAQAB\""
  ttl     = 1
  comment = "Resend DKIM for outgoing mail (OpenTofu)"
}

resource "cloudflare_dns_record" "family_resend_return_path" {
  for_each = toset(["send", "rsend"])

  zone_id = local.zones["family"]
  name    = "${each.key}.example.org"
  type    = "CNAME"
  content = "${each.key}.forge.rmta.net"
  proxied = false
  ttl     = 1
  comment = "Resend return-path / SPF for outgoing mail (OpenTofu)"
}

# Monitor first: reports to dmarc@ (routed to Gmail). Tighten to quarantine/reject once the
# reports show Resend and Cloudflare forwarding both passing.
resource "cloudflare_dns_record" "family_dmarc" {
  zone_id = local.zones["family"]
  name    = "_dmarc.example.org"
  type    = "TXT"
  content = "\"v=DMARC1; p=none; rua=mailto:dmarc@example.org\""
  ttl     = 1
  comment = "DMARC, monitor mode (OpenTofu)"
}
