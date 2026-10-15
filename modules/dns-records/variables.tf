variable "zone_id" {
  description = "Cloudflare zone ID."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{32}$", var.zone_id))
    error_message = "The zone_id must be a 32-character lowercase hexadecimal Cloudflare ID."
  }
}

variable "records" {
  description = "DNS records by key. name is a fully qualified name; ttl 1 means automatic; caa is used instead of content for CAA records."
  type = map(object({
    name     = string
    type     = string
    content  = optional(string)
    ttl      = optional(number, 1)
    proxied  = optional(bool, false)
    priority = optional(number)
    comment  = optional(string)
    caa = optional(object({
      flags = optional(number, 0)
      tag   = string
      value = string
    }))
  }))
  default = {}

  validation {
    condition     = alltrue([for r in values(var.records) : can(regex("^(\\*\\.)?([a-z0-9_]([a-z0-9_-]*[a-z0-9])?\\.)+[a-z]{2,}$", r.name))])
    error_message = "Every record name must be a lowercase fully qualified name such as www.example.com."
  }

  validation {
    condition     = alltrue([for r in values(var.records) : contains(["A", "AAAA", "CNAME", "TXT", "MX", "CAA"], r.type)])
    error_message = "The record type must be one of A, AAAA, CNAME, TXT, MX, CAA."
  }

  validation {
    condition     = alltrue([for r in values(var.records) : r.ttl == 1 || (r.ttl >= 60 && r.ttl <= 86400)])
    error_message = "The ttl must be 1 (automatic) or between 60 and 86400."
  }

  validation {
    condition     = alltrue([for r in values(var.records) : !r.proxied || (contains(["A", "AAAA", "CNAME"], r.type) && r.ttl == 1)])
    error_message = "Only A, AAAA and CNAME records can be proxied, and proxied records need ttl 1."
  }

  validation {
    condition     = alltrue([for r in values(var.records) : r.type == "CAA" ? (r.caa != null && r.content == null) : (r.caa == null && r.content != null)])
    error_message = "CAA records need caa and no content; other records need content and no caa."
  }

  validation {
    condition     = alltrue([for r in values(var.records) : (r.type == "MX") == (r.priority != null)])
    error_message = "MX records need priority; other records must not set it."
  }

  validation {
    condition     = alltrue([for r in values(var.records) : r.type != "A" || can(cidrhost("${coalesce(r.content, "x")}/32", 0))])
    error_message = "A records need an IPv4 address as content."
  }

  validation {
    condition     = alltrue([for r in values(var.records) : r.type != "AAAA" || can(cidrhost("${coalesce(r.content, "x")}/128", 0))])
    error_message = "AAAA records need an IPv6 address as content."
  }
}
