#!/usr/bin/env bash
# kubeadm init: kube-vip uses super-admin.conf until RBAC exists (kube-vip/kube-vip#684).
set -euo pipefail

if [[ -f /run/kubeadm/kubeadm.yaml ]]; then
  sed -i 's#path: /etc/kubernetes/admin.conf#path: /etc/kubernetes/super-admin.conf#' \
    /etc/kubernetes/manifests/kube-vip.yaml
fi
