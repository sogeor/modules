mock_provider "cloudflare" {}

variables {
  zone_id = "0123456789abcdef0123456789abcdef"
}

run "records" {
  command = apply

  variables {
    records = {
      apex = { name = "example.com", type = "A", content = "203.0.113.10", proxied = true }
      v6   = { name = "www.example.com", type = "AAAA", content = "2001:db8::10", ttl = 300 }
      mx   = { name = "example.com", type = "MX", content = "mail.example.com", priority = 10 }
      spf  = { name = "example.com", type = "TXT", content = "v=spf1 -all", comment = "No mail senders" }
      caa  = { name = "example.com", type = "CAA", caa = { tag = "issue", value = "letsencrypt.org" } }
    }
  }

  assert {
    condition     = toset(keys(output.records)) == toset(["apex", "v6", "mx", "spf", "caa"])
    error_message = "One record per key."
  }

  assert {
    condition     = cloudflare_dns_record.this["apex"].proxied && cloudflare_dns_record.this["apex"].ttl == 1
    error_message = "Proxied record keeps automatic TTL."
  }

  assert {
    condition     = cloudflare_dns_record.this["mx"].priority == 10
    error_message = "MX records keep their priority."
  }

  assert {
    condition     = cloudflare_dns_record.this["caa"].data.tag == "issue" && cloudflare_dns_record.this["caa"].data.flags == 0
    error_message = "CAA records are written to data."
  }
}

run "empty" {
  command = plan

  assert {
    condition     = length(cloudflare_dns_record.this) == 0
    error_message = "No records by default."
  }
}

run "bad_zone_id" {
  command = plan

  variables {
    zone_id = "CHANGE_ME"
  }

  expect_failures = [var.zone_id]
}

run "relative_name" {
  command = plan

  variables {
    records = { www = { name = "www", type = "CNAME", content = "example.com" } }
  }

  expect_failures = [var.records]
}

run "bad_type" {
  command = plan

  variables {
    records = { ns = { name = "sub.example.com", type = "NS", content = "ns.example.com" } }
  }

  expect_failures = [var.records]
}

run "bad_ttl" {
  command = plan

  variables {
    records = { a = { name = "a.example.com", type = "A", content = "203.0.113.1", ttl = 30 } }
  }

  expect_failures = [var.records]
}

run "proxied_txt" {
  command = plan

  variables {
    records = { t = { name = "t.example.com", type = "TXT", content = "x", proxied = true } }
  }

  expect_failures = [var.records]
}

run "proxied_with_ttl" {
  command = plan

  variables {
    records = { a = { name = "a.example.com", type = "A", content = "203.0.113.1", proxied = true, ttl = 300 } }
  }

  expect_failures = [var.records]
}

run "caa_without_data" {
  command = plan

  variables {
    records = { c = { name = "example.com", type = "CAA", content = "0 issue letsencrypt.org" } }
  }

  expect_failures = [var.records]
}

run "mx_without_priority" {
  command = plan

  variables {
    records = { m = { name = "example.com", type = "MX", content = "mail.example.com" } }
  }

  expect_failures = [var.records]
}

run "a_with_hostname" {
  command = plan

  variables {
    records = { a = { name = "a.example.com", type = "A", content = "host.example.com" } }
  }

  expect_failures = [var.records]
}

run "aaaa_with_ipv4" {
  command = plan

  variables {
    records = { a = { name = "a.example.com", type = "AAAA", content = "203.0.113.1" } }
  }

  expect_failures = [var.records]
}
