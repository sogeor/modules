locals {
  hostnames = toset([for a in values(var.apps) : a.hostname])

  order = concat(
    sort([for k, a in var.apps : k if a.path != null]),
    sort([for k, a in var.apps : k if a.path == null]),
  )

  ingress = concat(
    [for k in local.order : {
      hostname = var.apps[k].hostname
      service  = var.apps[k].service
      path     = var.apps[k].path
      origin_request = {
        http_host_header   = var.apps[k].origin_request.http_host_header
        origin_server_name = var.apps[k].origin_request.origin_server_name
        http2_origin       = var.apps[k].origin_request.http2_origin
        connect_timeout    = var.apps[k].origin_request.connect_timeout
        tls_timeout        = var.apps[k].origin_request.tls_timeout
        no_tls_verify      = var.apps[k].origin_request.no_tls_verify
      }
    }],
    [{ hostname = null, service = "http_status:404", path = null, origin_request = null }],
  )
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "this" {
  account_id = var.account_id
  name       = var.tunnel_name
  config_src = "cloudflare"
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "this" {
  account_id = var.account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.this.id

  config = {
    ingress = local.ingress
  }
}

resource "cloudflare_dns_record" "this" {
  for_each = local.hostnames

  zone_id = var.zone_id
  name    = each.value
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.this.id}.cfargotunnel.com"
  ttl     = 1
  proxied = true
  comment = var.comment
}

data "cloudflare_zero_trust_tunnel_cloudflared_token" "this" {
  account_id = var.account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.this.id
}
