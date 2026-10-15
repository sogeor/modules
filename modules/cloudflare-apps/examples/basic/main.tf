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

variable "account_id" {
  description = "Cloudflare account ID."
  type        = string
}

variable "zone_id" {
  description = "Cloudflare zone ID."
  type        = string
}

module "apps" {
  source = "../.."

  account_id  = var.account_id
  zone_id     = var.zone_id
  tunnel_name = "main"

  apps = {
    store = { hostname = "store.example.com", service = "http://ingress-nginx-controller.ingress-nginx.svc:80" }
  }
}

output "tunnel_id" {
  description = "Tunnel UUID."
  value       = module.apps.tunnel_id
}

output "tunnel_token" {
  description = "Token for cloudflared."
  value       = module.apps.tunnel_token
  sensitive   = true
}
