mock_provider "cloudflare" {
  mock_resource "cloudflare_zero_trust_tunnel_cloudflared" {
    defaults = {
      id = "f70ff985-a4ef-4643-bbbc-4a0ed4fc8415"
    }
  }

  mock_data "cloudflare_zero_trust_tunnel_cloudflared_token" {
    defaults = {
      token = "CHANGE_ME"
    }
  }
}

variables {
  account_id  = "0123456789abcdef0123456789abcdef"
  zone_id     = "fedcba9876543210fedcba9876543210"
  tunnel_name = "main"

  apps = {
    store = { hostname = "store.example.com", service = "http://ingress-nginx-controller.ingress-nginx.svc:80" }
    api   = { hostname = "store.example.com", path = "^/api/", service = "http://gateway.store.svc:8080" }
    grafana = {
      hostname       = "grafana.apps.example.com"
      service        = "https://oauth2-proxy.auth.svc:443"
      origin_request = { origin_server_name = "oauth2-proxy.auth.svc", http2_origin = true }
    }
  }
}

run "tunnel" {
  command = apply

  assert {
    condition     = cloudflare_zero_trust_tunnel_cloudflared.this.config_src == "cloudflare" && cloudflare_zero_trust_tunnel_cloudflared.this.name == "main"
    error_message = "The tunnel is remotely managed and named after the input."
  }

  assert {
    condition     = output.tunnel_cname == "f70ff985-a4ef-4643-bbbc-4a0ed4fc8415.cfargotunnel.com"
    error_message = "Hostnames point at the tunnel."
  }

  assert {
    condition     = output.hostnames == tolist(["grafana.apps.example.com", "store.example.com"])
    error_message = "One DNS record per distinct hostname."
  }

  assert {
    condition     = alltrue([for r in values(cloudflare_dns_record.this) : r.type == "CNAME" && r.proxied && r.ttl == 1 && r.content == output.tunnel_cname])
    error_message = "Hostname records are proxied CNAMEs to the tunnel."
  }

  assert {
    condition     = [for r in output.ingress : r.service] == ["http://gateway.store.svc:8080", "https://oauth2-proxy.auth.svc:443", "http://ingress-nginx-controller.ingress-nginx.svc:80", "http_status:404"]
    error_message = "Path rules come first, then key order, then the 404 catch-all."
  }

  assert {
    condition     = output.ingress[1].origin_request.http2_origin && !output.ingress[1].origin_request.no_tls_verify && output.ingress[3].hostname == null
    error_message = "Origin settings are passed through; TLS verification stays on."
  }

  assert {
    condition     = output.tunnel_token == "CHANGE_ME"
    error_message = "The tunnel token comes from the token data source."
  }
}

run "no_tls_verify_with_reason" {
  command = plan

  variables {
    apps = {
      bao = { hostname = "bao.example.com", service = "https://openbao.openbao.svc:8200", origin_request = { no_tls_verify = true, no_tls_verify_reason = "Self-signed bootstrap certificate" } }
    }
  }

  assert {
    condition     = output.ingress[0].origin_request.no_tls_verify
    error_message = "A justified no_tls_verify is accepted."
  }
}

run "no_tls_verify_without_reason" {
  command = plan

  variables {
    apps = {
      bao = { hostname = "bao.example.com", service = "https://openbao.openbao.svc:8200", origin_request = { no_tls_verify = true } }
    }
  }

  expect_failures = [var.apps]
}

run "no_apps" {
  command = plan

  variables {
    apps = {}
  }

  expect_failures = [var.apps]
}

run "bad_service" {
  command = plan

  variables {
    apps = { a = { hostname = "a.example.com", service = "localhost:8080" } }
  }

  expect_failures = [var.apps]
}

run "bad_hostname" {
  command = plan

  variables {
    apps = { a = { hostname = "a", service = "http://a.svc" } }
  }

  expect_failures = [var.apps]
}

run "duplicate_route" {
  command = plan

  variables {
    apps = {
      a = { hostname = "a.example.com", service = "http://a.svc" }
      b = { hostname = "a.example.com", service = "http://b.svc" }
    }
  }

  expect_failures = [var.apps]
}

run "bad_account_id" {
  command = plan

  variables {
    account_id = "CHANGE_ME"
  }

  expect_failures = [var.account_id]
}

run "bad_tunnel_name" {
  command = plan

  variables {
    tunnel_name = "Main_Cluster"
  }

  expect_failures = [var.tunnel_name]
}
