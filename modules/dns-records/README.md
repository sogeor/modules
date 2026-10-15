# dns-records

Manages DNS records in a Cloudflare zone: A, AAAA, CNAME, TXT, MX and CAA.

- Names are fully qualified; `ttl = 1` means automatic.
- Only A, AAAA and CNAME records can be proxied, and proxied records keep the automatic TTL.
- CAA records take `caa` instead of `content`; MX records need `priority`.
- Internal names (`lab` zone) are served by split DNS in the mesh, not by this module.

```hcl
module "dns" {
  source = "git::https://github.com/sogeor/modules.git//modules/dns-records?ref=modules-v0.1.0"

  zone_id = var.zone_id

  records = {
    docs = { name = "docs.example.com", type = "CNAME", content = "example.github.io" }
    caa  = { name = "example.com", type = "CAA", caa = { tag = "issue", value = "letsencrypt.org" } }
  }
}
```

Options: [Configuration](../../docs/configuration.md#dns-records).

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

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| zone_id | Cloudflare zone ID. | `string` | n/a | yes |
| records | DNS records by key. name is a fully qualified name; ttl 1 means automatic; caa is used instead of content for CAA records. | ```map(object({ name = string type = string content = optional(string) ttl = optional(number, 1) proxied = optional(bool, false) priority = optional(number) comment = optional(string) caa = optional(object({ flags = optional(number, 0) tag = string value = string })) }))``` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| records | Created records by key: id, name and type. |
<!-- END_TF_DOCS -->
