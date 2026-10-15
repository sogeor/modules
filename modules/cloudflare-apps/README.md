# cloudflare-apps

Publishes cluster services through a remotely managed Cloudflare Tunnel: creates the tunnel, its ingress rules and
a proxied CNAME per hostname, and returns the token for `cloudflared` in the cluster.

- The cluster has no public load balancers; `cloudflared` connects out to Cloudflare.
- Ingress rules: path rules first, then the rest in key order, then `http_status:404`.
- Origin TLS verification stays on; `no_tls_verify` needs `no_tls_verify_reason`.
- Uses only Tunnel and DNS: no Access, WAF or WARP.

```hcl
module "apps" {
  source = "git::https://github.com/sogeor/modules.git//modules/cloudflare-apps?ref=modules-v0.1.0"

  account_id  = var.account_id
  zone_id     = var.zone_id
  tunnel_name = "main"

  apps = {
    store = { hostname = "store.example.com", service = "http://ingress-nginx-controller.ingress-nginx.svc:80" }
  }
}
```

Options: [Configuration](../../docs/configuration.md#cloudflare-apps).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.10.0 |
| cloudflare | = 5.27.0 |

## Providers

| Name | Version |
| ---- | ------- |
| cloudflare | = 5.27.0 |

## Resources

| Name | Type |
| ---- | ---- |
| [cloudflare_dns_record.this](https://registry.terraform.io/providers/cloudflare/cloudflare/5.27.0/docs/resources/dns_record) | resource |
| [cloudflare_zero_trust_tunnel_cloudflared.this](https://registry.terraform.io/providers/cloudflare/cloudflare/5.27.0/docs/resources/zero_trust_tunnel_cloudflared) | resource |
| [cloudflare_zero_trust_tunnel_cloudflared_config.this](https://registry.terraform.io/providers/cloudflare/cloudflare/5.27.0/docs/resources/zero_trust_tunnel_cloudflared_config) | resource |
| [cloudflare_zero_trust_tunnel_cloudflared_token.this](https://registry.terraform.io/providers/cloudflare/cloudflare/5.27.0/docs/data-sources/zero_trust_tunnel_cloudflared_token) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| account_id | Cloudflare account ID. | `string` | n/a | yes |
| apps | Public hostnames by key, routed path rules first, then in key order, before the final http_status:404 rule. service is the in-cluster URL; no_tls_verify needs no_tls_verify_reason. | ```map(object({ hostname = string service = string path = optional(string) origin_request = optional(object({ http_host_header = optional(string) origin_server_name = optional(string) http2_origin = optional(bool) connect_timeout = optional(number) tls_timeout = optional(number) no_tls_verify = optional(bool, false) no_tls_verify_reason = optional(string) }), {}) }))``` | n/a | yes |
| tunnel_name | Tunnel name, usually the cluster name. | `string` | n/a | yes |
| zone_id | Cloudflare zone ID for the public hostnames. | `string` | n/a | yes |
| comment | Comment on the DNS records created for the hostnames. | `string` | `"Managed by OpenTofu: Cloudflare Tunnel"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| hostnames | Published hostnames. |
| ingress | Ingress rules in routing order, ending with http_status:404. |
| tunnel_cname | Target of the hostname CNAME records. |
| tunnel_id | Tunnel UUID. |
| tunnel_token | Token for cloudflared (TUNNEL_TOKEN); store it in OpenBao or a SOPS file. |
<!-- END_TF_DOCS -->
