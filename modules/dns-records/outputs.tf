output "records" {
  description = "Created records by key: id, name and type."
  value       = { for k, r in cloudflare_dns_record.this : k => { id = r.id, name = r.name, type = r.type } }
}
