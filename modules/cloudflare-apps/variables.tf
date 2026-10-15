variable "account_id" {
  description = "Cloudflare account ID."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{32}$", var.account_id))
    error_message = "The account_id must be a 32-character lowercase hexadecimal Cloudflare ID."
  }
}

variable "zone_id" {
  description = "Cloudflare zone ID for the public hostnames."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{32}$", var.zone_id))
    error_message = "The zone_id must be a 32-character lowercase hexadecimal Cloudflare ID."
  }
}

variable "tunnel_name" {
  description = "Tunnel name, usually the cluster name."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$", var.tunnel_name))
    error_message = "The tunnel_name must be a lowercase DNS label."
  }
}

variable "apps" {
  description = "Public hostnames by key, routed path rules first, then in key order, before the final http_status:404 rule. service is the in-cluster URL; no_tls_verify needs no_tls_verify_reason."
  type = map(object({
    hostname = string
    service  = string
    path     = optional(string)
    origin_request = optional(object({
      http_host_header     = optional(string)
      origin_server_name   = optional(string)
      http2_origin         = optional(bool)
      connect_timeout      = optional(number)
      tls_timeout          = optional(number)
      no_tls_verify        = optional(bool, false)
      no_tls_verify_reason = optional(string)
    }), {})
  }))

  validation {
    condition     = length(var.apps) > 0
    error_message = "At least one app is required."
  }

  validation {
    condition     = alltrue([for a in values(var.apps) : can(regex("^([a-z0-9]([a-z0-9-]*[a-z0-9])?\\.)+[a-z]{2,}$", a.hostname))])
    error_message = "Every hostname must be a lowercase fully qualified name such as app.example.com."
  }

  validation {
    condition     = alltrue([for a in values(var.apps) : can(regex("^((https?|tcp|ssh|rdp|smb|unix|unix\\+tls)://.+|http_status:[1-5][0-9]{2})$", a.service))])
    error_message = "The service must be a URL with a supported scheme or http_status:CODE."
  }

  validation {
    condition     = alltrue([for a in values(var.apps) : !a.origin_request.no_tls_verify || trimspace(a.origin_request.no_tls_verify_reason == null ? "" : a.origin_request.no_tls_verify_reason) != ""])
    error_message = "Disabling origin TLS verification needs no_tls_verify_reason."
  }

  validation {
    condition     = length(distinct([for a in values(var.apps) : "${a.hostname}${a.path == null ? "" : a.path}"])) == length(var.apps)
    error_message = "Every hostname and path pair must be unique."
  }
}

variable "comment" {
  description = "Comment on the DNS records created for the hostnames."
  type        = string
  default     = "Managed by OpenTofu: Cloudflare Tunnel"
}
