output "tunnel_id" {
  description = "Tunnel UUID."
  value       = cloudflare_zero_trust_tunnel_cloudflared.this.id
}

output "tunnel_cname" {
  description = "Target of the hostname CNAME records."
  value       = "${cloudflare_zero_trust_tunnel_cloudflared.this.id}.cfargotunnel.com"
}

output "tunnel_token" {
  description = "Token for cloudflared (TUNNEL_TOKEN); store it in OpenBao or a SOPS file."
  value       = data.cloudflare_zero_trust_tunnel_cloudflared_token.this.token
  sensitive   = true
}

output "hostnames" {
  description = "Published hostnames."
  value       = sort(tolist(local.hostnames))
}

output "ingress" {
  description = "Ingress rules in routing order, ending with http_status:404."
  value       = local.ingress
}
