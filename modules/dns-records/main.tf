resource "cloudflare_dns_record" "this" {
  for_each = var.records

  zone_id  = var.zone_id
  name     = each.value.name
  type     = each.value.type
  content  = each.value.content
  ttl      = each.value.ttl
  proxied  = contains(["A", "AAAA", "CNAME"], each.value.type) ? each.value.proxied : null
  priority = each.value.priority
  comment  = each.value.comment
  data     = each.value.caa == null ? null : { flags = each.value.caa.flags, tag = each.value.caa.tag, value = each.value.caa.value }
}
