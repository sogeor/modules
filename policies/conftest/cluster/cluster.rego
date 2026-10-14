package main

import data.matrix

cp_names := sort([name | some name, p in input.pools; p.role == "control-plane"])

default_mechanism := object.get(matrix.providers, [input.pools[cp_names[0]].provider, "default_mechanism"], "opentofu") if {
	count(cp_names) > 0
} else := "opentofu"

mechanism := object.get(input, "mechanism", default_mechanism)

profiles := object.get(input, "profiles", ["core"])

multisite_enabled := object.get(input, ["control_plane_multisite", "enabled"], false)

multisite_reason := trim_space(object.get(input, ["control_plane_multisite", "reason"], ""))

cp_count := sum([object.get(p, "count", 0) | some p in input.pools; p.role == "control-plane"])

cp_sites := {p.site | some p in input.pools; p.role == "control-plane"}

has_field(obj, key) if {
	_ = obj[key]
}

image_status(p) := object.get(matrix.images, [p.os, p.provider], null)

bad_bounds(a) if a.min < 0

bad_bounds(a) if a.max < 1

bad_bounds(a) if a.min > a.max

deny contains sprintf("[unknown-profile] profile %s is not one of: %s", [pr, concat(", ", matrix.profiles)]) if {
	some pr in profiles
	not pr in matrix.profiles
}

deny contains sprintf("[unknown-os] pool %s: os %s is not supported", [name, p.os]) if {
	some name, p in input.pools
	not matrix.images[p.os]
}

deny contains sprintf("[unknown-provider] pool %s: provider %s is not supported", [name, p.provider]) if {
	some name, p in input.pools
	not matrix.providers[p.provider]
}

deny contains sprintf("[unknown-size] pool %s: size %s is not supported", [name, p.size]) if {
	some name, p in input.pools
	not matrix.sizes[p.size]
}

deny contains sprintf("[os-distribution] pool %s: os %s is not allowed for distribution %s", [name, p.os, input.distribution]) if {
	some name, p in input.pools
	not p.os in object.get(matrix.distributions, [input.distribution, "os"], [])
}

deny contains sprintf("[image-unsupported] pool %s: no image exists or is planned for os %s on provider %s", [name, p.os, p.provider]) if {
	some name, p in input.pools
	matrix.images[p.os]
	matrix.providers[p.provider]
	image_status(p) == null
}

warn contains sprintf("[image-planned] pool %s: the image for os %s on provider %s is planned, not available", [name, p.os, p.provider]) if {
	some name, p in input.pools
	image_status(p) == "planned"
}

deny contains sprintf("[talos-byo-custom-image] pool %s: talos on byo requires custom_image_supported: true", [name]) if {
	some name, p in input.pools
	p.os == "talos"
	p.provider == "byo"
	not object.get(p, "custom_image_supported", false)
}

deny contains sprintf("[count-or-autoscale] pool %s: set exactly one of count and autoscale", [name]) if {
	some name, p in input.pools
	has_field(p, "count")
	has_field(p, "autoscale")
}

deny contains sprintf("[count-or-autoscale] pool %s: set exactly one of count and autoscale", [name]) if {
	some name, p in input.pools
	not has_field(p, "count")
	not has_field(p, "autoscale")
}

deny contains sprintf("[autoscale-bounds] pool %s: autoscale requires 0 <= min <= max and max >= 1", [name]) if {
	some name, p in input.pools
	bad_bounds(p.autoscale)
}

deny contains sprintf("[autoscale-mechanism] pool %s: autoscale requires mechanism capi (current: %s)", [name, mechanism]) if {
	some name, p in input.pools
	p.autoscale
	mechanism != "capi"
}

deny contains sprintf("[control-plane-autoscale] pool %s: control-plane pools use count, not autoscale", [name]) if {
	some name, p in input.pools
	p.role == "control-plane"
	p.autoscale
}

deny contains sprintf("[mechanism-provider] pool %s: provider %s does not support mechanism %s", [name, p.provider, mechanism]) if {
	some name, p in input.pools
	matrix.providers[p.provider]
	not mechanism in matrix.providers[p.provider].mechanisms
}

deny contains "[control-plane-missing] at least one pool with role control-plane is required" if {
	count(cp_names) == 0
}

deny contains sprintf("[topology-control-plane] topology single requires exactly 1 control-plane node (current: %d)", [cp_count]) if {
	input.topology == "single"
	count(cp_names) > 0
	cp_count != 1
}

deny contains sprintf("[topology-control-plane] topology ha requires an odd number of control-plane nodes, at least 3 (current: %d)", [cp_count]) if {
	input.topology == "ha"
	cp_count < 3
}

deny contains sprintf("[topology-control-plane] topology ha requires an odd number of control-plane nodes, at least 3 (current: %d)", [cp_count]) if {
	input.topology == "ha"
	cp_count % 2 == 0
}

deny contains sprintf("[control-plane-multisite] control-plane pools span sites %s; set control_plane_multisite.enabled: true with a reason", [concat(", ", sort(cp_sites))]) if {
	count(cp_sites) > 1
	not multisite_enabled
}

deny contains "[control-plane-multisite] control_plane_multisite.reason is required when control_plane_multisite.enabled is true" if {
	multisite_enabled
	multisite_reason == ""
}
