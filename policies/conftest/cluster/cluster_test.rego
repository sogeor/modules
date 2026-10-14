package main

base := {
	"cluster": "lab",
	"cluster_id": 5,
	"distribution": "kubeadm",
	"kubernetes_version": "1.37.1",
	"topology": "single",
	"pools": {"cp": {"role": "control-plane", "os": "ubuntu-2404", "provider": "proxmox", "site": "home", "size": "m", "count": 1}},
}

cp(patch) := object.union(base, {"pools": {"cp": object.union(base.pools.cp, patch)}})

rules(results) := {substring(m, 1, indexof(m, "]") - 1) | some m in results}

test_base_is_valid if {
	count(deny) == 0 with input as base
	count(warn) == 0 with input as base
}

test_default_mechanism_is_capi_on_proxmox if {
	mechanism == "capi" with input as base
}

test_unknown_values if {
	cluster := object.union(cp({"os": "debian-13", "provider": "hetzner", "size": "huge"}), {"profiles": ["core", "nope"]})
	r := rules(deny) with input as cluster
	{"unknown-profile", "unknown-os", "unknown-provider", "unknown-size"} - r == set()
}

test_os_distribution if {
	"os-distribution" in rules(deny) with input as object.union(base, {"distribution": "talos"})
}

test_image_unsupported if {
	"image-unsupported" in rules(deny) with input as cp({"os": "astra-18", "provider": "selectel", "site": "selectel-ru-9"})
}

test_image_planned_is_warning if {
	cluster := cp({"os": "ubuntu-2604"})
	count(deny) == 0 with input as cluster
	"image-planned" in rules(warn) with input as cluster
}

test_talos_byo_custom_image if {
	cluster := object.union(cp({"os": "talos", "provider": "byo", "site": "vds"}), {"distribution": "talos"})
	"talos-byo-custom-image" in rules(deny) with input as cluster
	count(deny) == 0 with input as object.union(cp({"os": "talos", "provider": "byo", "site": "vds", "custom_image_supported": true}), {"distribution": "talos"})
}

test_count_or_autoscale if {
	cluster := object.union(base, {"pools": {"workers": {"role": "worker", "os": "ubuntu-2404", "provider": "proxmox", "site": "home", "size": "m"}}})
	"count-or-autoscale" in rules(deny) with input as cluster
}

test_autoscale_bounds if {
	cluster := object.union(base, {"pools": {"workers": {"role": "worker", "os": "ubuntu-2404", "provider": "proxmox", "site": "home", "size": "m", "autoscale": {"min": 3, "max": 1}}}})
	"autoscale-bounds" in rules(deny) with input as cluster
}

test_autoscale_mechanism if {
	cluster := object.union(base, {"mechanism": "opentofu", "pools": {"workers": {"role": "worker", "os": "ubuntu-2404", "provider": "proxmox", "site": "home", "size": "m", "autoscale": {"min": 0, "max": 2}}}})
	"autoscale-mechanism" in rules(deny) with input as cluster
}

test_control_plane_autoscale if {
	cluster := {
		"cluster": "lab", "cluster_id": 5, "distribution": "kubeadm", "kubernetes_version": "1.37.1", "topology": "single",
		"pools": {"cp": {"role": "control-plane", "os": "ubuntu-2404", "provider": "proxmox", "site": "home", "size": "m", "autoscale": {"min": 1, "max": 1}}},
	}
	"control-plane-autoscale" in rules(deny) with input as cluster
}

test_mechanism_provider if {
	cluster := object.union(cp({"provider": "byo", "site": "vds"}), {"mechanism": "capi"})
	"mechanism-provider" in rules(deny) with input as cluster
}

test_control_plane_missing if {
	cluster := object.union(object.remove(base, ["pools"]), {"pools": {"workers": {"role": "worker", "os": "ubuntu-2404", "provider": "proxmox", "site": "home", "size": "m", "count": 1}}})
	"control-plane-missing" in rules(deny) with input as cluster
}

test_single_control_plane_count if {
	"topology-control-plane" in rules(deny) with input as cp({"count": 2})
}

test_ha_control_plane_count if {
	"topology-control-plane" in rules(deny) with input as object.union(cp({"count": 4}), {"topology": "ha"})
	"topology-control-plane" in rules(deny) with input as object.union(cp({"count": 1}), {"topology": "ha"})
	count(deny) == 0 with input as object.union(cp({"count": 3}), {"topology": "ha"})
}

multisite := {
	"cluster": "lab", "cluster_id": 5, "distribution": "talos", "kubernetes_version": "1.37.1", "topology": "ha",
	"pools": {
		"home": {"role": "control-plane", "os": "talos", "provider": "proxmox", "site": "home", "size": "m", "count": 1},
		"cloud": {"role": "control-plane", "os": "talos", "provider": "selectel", "site": "selectel-ru-9", "size": "m", "count": 2},
	},
}

test_control_plane_multisite if {
	"control-plane-multisite" in rules(deny) with input as multisite
	"control-plane-multisite" in rules(deny) with input as object.union(multisite, {"control_plane_multisite": {"enabled": true}})
	count(deny) == 0 with input as object.union(multisite, {"control_plane_multisite": {"enabled": true, "reason": "Measured latency below 10 ms."}})
}
