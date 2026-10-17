# Security

## What is guaranteed

| Property | How |
|---|---|
| No secrets in the repository | gitleaks in pre-commit and CI, push protection |
| No personal values | Addresses, domains, IDs are variables without defaults; examples use RFC 5737 and `example.com` |
| Pinned dependencies | Exact provider versions, actions by full SHA, hash-locked Python tools, checksum-verified binaries |
| Invalid clusters are rejected before any resource exists | JSON Schema and validations of the cluster description (with `cluster-spec`) |
| Tests never touch infrastructure | `tofu test` with mock providers; CI has no infrastructure credentials |
| Static analysis | Checkov, Trivy, Semgrep and gitleaks through `security-lite` |
| Sensitive outputs | Machine secrets, talosconfig and kubeconfig are `sensitive = true` |
| Verified images | Talos ISO checked by SHA-256 before use; templates selected only by tags and CI build names |
| Encrypted Talos disks | STATE and EPHEMERAL volumes use LUKS2 with a TPM-sealed key by default (`talos-cluster`) |
| Kubernetes secrets encrypted in etcd | Talos default (secretbox key in the machine secrets) |
| No kube-proxy, policy-capable CNI from the first boot | Cilium with kube-proxy replacement installed at bootstrap |
| No inbound ports for published services | `cloudflare-apps` publishes through an outbound-only Cloudflare Tunnel; hostnames without a rule get `404` |
| Origin TLS verified by default | `no_tls_verify` is off and needs a written reason to be turned on |
| No SSH on Talos in the cloud | `providers/selectel` refuses a key pair for Talos clusters; flavors are private to the project |
| Tunnel token not printed | `tunnel_token` is `sensitive = true` |
| Least exposure of the Talos API | Talos has no SSH; access only with the client certificate from `talosconfig` |

## What is not guaranteed

- Security of the state where consumers store outputs: state encryption is configured in the root
  modules of consuming repositories.
- Correctness of upstream providers and Cluster API providers.
- Network isolation of created nodes beyond what the module inputs request.
- Full strength of TPM disk encryption: without SecureBoot the key is bound to PCR 7 in the
  "SecureBoot disabled" state, so it protects a disk copied away from its VM, but not against someone who can
  boot a modified system on the same VM. SecureBoot for Talos VMs is planned ([ROADMAP](https://github.com/sogeor/modules/blob/master/ROADMAP.md)).
- On Proxmox the vTPM state lives on the same storage as the disks; copying the whole VM copies the key too.
- The tunnel token and the Cloudflare API token grant control over published hostnames; their storage and
  rotation are up to the consuming repository and the secret store.
- Cloudflare terminates TLS of published hostnames and sees the traffic in clear text.
- The Cilium chart is pinned by version; its archive is not verified by digest by the Helm provider.

## Assurance case

| Threat | Trust boundary | Mitigation | CWE |
|---|---|---|---|
| Credentials leaked through code or logs | repository → public | gitleaks, sensitive outputs, no credentials in CI | CWE-798, CWE-532 |
| Compromised dependency | registry → CI and consumers | exact pins, SHA pins, hashes, Renovate review | CWE-829 |
| Malicious workflow change | contributor → CI | minimal `permissions`, `persist-credentials: false`, zizmor, required review via ruleset | CWE-269 |
| Misconfigured cluster (budget, quorum) | description → infrastructure | validations: `autoscale.max` required, odd control plane for `ha` | CWE-20 |

Principles: least privilege, secure defaults, validation before creation, no static credentials.
Vulnerability reporting: [SECURITY.md](https://github.com/sogeor/modules/blob/master/SECURITY.md).
