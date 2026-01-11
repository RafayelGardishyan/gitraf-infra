#!/bin/bash
# k3s installation script for gitraf
# Tailscale-only access, no external load balancer

set -e

echo "=== Installing k3s for gitraf ==="

# Get Tailscale IP
TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "")
if [ -z "$TAILSCALE_IP" ]; then
    echo "ERROR: Tailscale not running or no IPv4 address"
    exit 1
fi
echo "Tailscale IP: $TAILSCALE_IP"

# Install k3s with:
# - Disable traefik (we'll use our own ingress or direct NodePort)
# - Disable servicelb (no external LB needed)
# - Bind to Tailscale interface only
# - Use flannel with host-gw for better performance
echo "Installing k3s..."
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC=" \
    --disable traefik \
    --disable servicelb \
    --node-ip $TAILSCALE_IP \
    --advertise-address $TAILSCALE_IP \
    --bind-address $TAILSCALE_IP \
    --flannel-iface tailscale0 \
    --write-kubeconfig-mode 644 \
    " sh -

# Wait for k3s to be ready
echo "Waiting for k3s to be ready..."
sleep 10
until kubectl get nodes 2>/dev/null | grep -q " Ready"; do
    echo "  Waiting for node to be ready..."
    sleep 5
done

echo "k3s installed successfully!"
kubectl get nodes

# Create gitraf namespace
echo "Creating gitraf namespace..."
kubectl create namespace gitraf --dry-run=client -o yaml | kubectl apply -f -

# Show cluster info
echo ""
echo "=== Cluster Info ==="
kubectl cluster-info
echo ""
echo "=== Nodes ==="
kubectl get nodes -o wide
echo ""
echo "k3s installation complete!"
echo "Kubeconfig is at: /etc/rancher/k3s/k3s.yaml"
