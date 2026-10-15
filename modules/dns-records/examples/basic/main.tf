terraform {
  required_version = ">= 1.10.0"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "= 5.27.0"
    }
  }
}

# CLOUDFLARE_API_TOKEN
provider "cloudflare" {}

variable "zone_id" {
  description = "Cloudflare zone ID."
  type        = string
}

module "dns" {
  source = "../.."

  zone_id = var.zone_id

  records = {
    docs = { name = "docs.example.com", type = "CNAME", content = "example.github.io" }
    caa  = { name = "example.com", type = "CAA", caa = { tag = "issue", value = "letsencrypt.org" } }
    spf  = { name = "example.com", type = "TXT", content = "v=spf1 -all" }
  }
}

output "records" {
  description = "Created records."
  value       = module.dns.records
}
