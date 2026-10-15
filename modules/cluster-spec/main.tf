locals {
  matrix = yamldecode(file("${path.module}/matrix.yaml")).matrix

  c        = var.cluster
  pools    = local.c.pools
  cp_pools = { for name, p in local.pools : name => p if p.role == "control-plane" }

  cp_provider = try(local.cp_pools[sort(keys(local.cp_pools))[0]].provider, null)
  mechanism   = coalesce(local.c.mechanism, try(local.matrix.providers[local.cp_provider].default_mechanism, null), "opentofu")

  cp_count = sum(concat([0], [for p in values(local.cp_pools) : coalesce(p.count, 0)]))
  cp_sites = distinct([for p in values(local.cp_pools) : p.site])

  providers = sort(distinct([for p in values(local.pools) : p.provider]))

  multisite_enabled = try(local.c.control_plane_multisite.enabled, false)
  multisite_reason  = trimspace(try(local.c.control_plane_multisite.reason, ""))

  image_status = { for name, p in local.pools : name => try(local.matrix.images[p.os][p.provider], null) }

  violations = concat(
    [for pr in local.c.profiles : {
      rule    = "unknown-profile"
      message = "profile ${pr} is not one of: ${join(", ", local.matrix.profiles)}"
    } if !contains(local.matrix.profiles, pr)],

    [for name, p in local.pools : {
      rule    = "unknown-os"
      message = "pool ${name}: os ${p.os} is not one of: ${join(", ", keys(local.matrix.images))}"
    } if !contains(keys(local.matrix.images), p.os)],

    [for name, p in local.pools : {
      rule    = "unknown-provider"
      message = "pool ${name}: provider ${p.provider} is not one of: ${join(", ", keys(local.matrix.providers))}"
    } if !contains(keys(local.matrix.providers), p.provider)],

    [for name, p in local.pools : {
      rule    = "unknown-size"
      message = "pool ${name}: size ${p.size} is not one of: ${join(", ", keys(local.matrix.sizes))}"
    } if !contains(keys(local.matrix.sizes), p.size)],

    [for name, p in local.pools : {
      rule    = "os-distribution"
      message = "pool ${name}: os ${p.os} is not allowed for distribution ${local.c.distribution} (allowed: ${join(", ", local.matrix.distributions[local.c.distribution].os)})"
    } if !contains(local.matrix.distributions[local.c.distribution].os, p.os)],

    [for name, p in local.pools : {
      rule    = "image-unsupported"
      message = "pool ${name}: no image exists or is planned for os ${p.os} on provider ${p.provider}"
    } if local.image_status[name] == null && contains(keys(local.matrix.images), p.os) && contains(keys(local.matrix.providers), p.provider)],

    [for name, p in local.pools : {
      rule    = "image-planned"
      message = "pool ${name}: the image for os ${p.os} on provider ${p.provider} is planned, not available"
    } if local.image_status[name] == "planned" && !var.allow_planned_images],


    [for name, p in local.pools : {
      rule    = "talos-byo-custom-image"
      message = "pool ${name}: talos on byo requires custom_image_supported: true"
    } if p.os == "talos" && p.provider == "byo" && !p.custom_image_supported],

    [for name, p in local.pools : {
      rule    = "count-or-autoscale"
      message = "pool ${name}: set exactly one of count and autoscale"
    } if(p.count == null) == (p.autoscale == null)],

    [for name, p in local.pools : {
      rule    = "autoscale-bounds"
      message = "pool ${name}: autoscale requires 0 <= min <= max and max >= 1"
    } if try(p.autoscale.min < 0 || p.autoscale.max < 1 || p.autoscale.min > p.autoscale.max, false)],

    [for name, p in local.pools : {
      rule    = "autoscale-mechanism"
      message = "pool ${name}: autoscale requires mechanism capi (current: ${local.mechanism})"
    } if p.autoscale != null && local.mechanism != "capi"],

    [for name, p in local.pools : {
      rule    = "control-plane-autoscale"
      message = "pool ${name}: control-plane pools use count, not autoscale"
    } if p.role == "control-plane" && p.autoscale != null],

    [for name, p in local.pools : {
      rule    = "mechanism-provider"
      message = "pool ${name}: provider ${p.provider} does not support mechanism ${local.mechanism}"
    } if !contains(try(local.matrix.providers[p.provider].mechanisms, [local.mechanism]), local.mechanism)],

    local.mechanism == "capi" && length(local.providers) > 1 ? [{
      rule    = "capi-single-provider"
      message = "mechanism capi needs all pools on one provider (current: ${join(", ", local.providers)})"
    }] : [],

    local.mechanism == "capi" && local.c.distribution == "k3s" ? [{
      rule    = "capi-distribution"
      message = "distribution k3s is not supported with mechanism capi; use mechanism opentofu"
    }] : [],

    length(local.cp_pools) == 0 ? [{
      rule    = "control-plane-missing"
      message = "at least one pool with role control-plane is required"
    }] : [],

    local.c.topology == "single" && length(local.cp_pools) > 0 && local.cp_count != 1 ? [{
      rule    = "topology-control-plane"
      message = "topology single requires exactly 1 control-plane node (current: ${local.cp_count})"
    }] : [],

    local.c.topology == "ha" && (local.cp_count < 3 || local.cp_count % 2 == 0) ? [{
      rule    = "topology-control-plane"
      message = "topology ha requires an odd number of control-plane nodes, at least 3 (current: ${local.cp_count})"
    }] : [],

    length(local.cp_sites) > 1 && !local.multisite_enabled ? [{
      rule    = "control-plane-multisite"
      message = "control-plane pools span sites ${join(", ", local.cp_sites)}; set control_plane_multisite.enabled: true with a reason"
    }] : [],

    local.multisite_enabled && local.multisite_reason == "" ? [{
      rule    = "control-plane-multisite"
      message = "control_plane_multisite.reason is required when control_plane_multisite.enabled is true"
    }] : [],
  )

  warnings = [for name, p in local.pools : {
    rule    = "image-planned"
    message = "pool ${name}: the image for os ${p.os} on provider ${p.provider} is planned, not available"
  } if local.image_status[name] == "planned" && var.allow_planned_images]

  spec = {
    cluster            = local.c.cluster
    cluster_id         = local.c.cluster_id
    distribution       = local.c.distribution
    kubernetes_version = local.c.kubernetes_version
    topology           = local.c.topology
    profiles           = local.c.profiles
    mechanism          = local.mechanism

    network = {
      pod_cidr     = "10.${local.c.cluster_id * 10}.0.0/16"
      service_cidr = "10.${local.c.cluster_id * 10 + 1}.0.0/16"
    }

    control_plane = {
      count             = local.cp_count
      sites             = local.cp_sites
      provider          = local.cp_provider
      workloads_allowed = local.c.topology == "single"
    }

    labels = merge(
      {
        "sogeor.com/cluster"      = local.c.cluster
        "sogeor.com/distribution" = local.c.distribution
        "sogeor.com/topology"     = local.c.topology
      },
      { for pr in local.c.profiles : "sogeor.com/profile-${pr}" => "true" },
    )

    pools = { for name, p in local.pools : name => {
      role          = p.role
      os            = p.os
      provider      = p.provider
      site          = p.site
      size          = p.size
      cpu           = try(local.matrix.sizes[p.size].cpu, null)
      memory_mb     = try(local.matrix.sizes[p.size].memory_mb, null)
      disk_gb       = try(local.matrix.sizes[p.size].disk_gb, null)
      count         = p.count
      autoscale     = p.autoscale
      labels        = merge(p.labels, { "sogeor.com/pool" = name })
      taints        = p.taints
      image_status  = local.image_status[name]
      mesh_required = p.site != "home"
    } }
  }
}
