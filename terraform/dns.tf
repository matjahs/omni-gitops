resource "technitium_dns_zone" "main" {
  name                       = "lab.mxe11.nl"
  type                       = "Primary"
  use_soa_serial_date_scheme = true
}

resource "technitium_dns_zone_record" "a" {
  type       = "A"
  for_each   = local.resolved_control_endpoints
  domain     = "api.lab.mxe11.nl"
  ip_address = each.value
  comments   = "A record for api.lab.mxe11.nl pointing to ${each.key}"
  ttl        = 3600
  zone       = technitium_dns_zone.main.name
  depends_on = [technitium_dns_zone.main]
}

resource "technitium_dns_zone_record" "main_ptr" {
  type       = "PTR"
  for_each   = local.resolved_control_endpoints
  domain     = "${each.value}.in-addr.arpa"
  ip_address = each.value
  comments   = "PTR record for ${each.key}"
  ttl        = 3600
  zone       = technitium_dns_zone.main.name
  depends_on = [technitium_dns_zone_record.a]
}
