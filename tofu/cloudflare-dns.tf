locals {
  # Zone IDs are identifiers, not secrets.
  zones = {
    lab      = "00000000000000000000000000000000"
    family   = "00000000000000000000000000000000"
    personal = "00000000000000000000000000000000"
  }

  # Domains that will never send email: publish "reject everything claiming to be us".
  no_mail = {
    lab      = "example.net"
    personal = "example.com"
  }
}

resource "cloudflare_dns_record" "no_mail_spf" {
  for_each = local.no_mail
  zone_id  = local.zones[each.key]
  name     = each.value
  type     = "TXT"
  content  = "\"v=spf1 -all\""
  ttl      = 1
  comment  = "No mail sent from this domain (OpenTofu)"
}

resource "cloudflare_dns_record" "no_mail_dmarc" {
  for_each = local.no_mail
  zone_id  = local.zones[each.key]
  name     = "_dmarc.${each.value}"
  type     = "TXT"
  content  = "\"v=DMARC1; p=reject; sp=reject; adkim=s; aspf=s\""
  ttl      = 1
  comment  = "Reject spoofed mail (OpenTofu)"
}
