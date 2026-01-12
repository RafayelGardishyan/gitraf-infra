# gitraf-infra

Infrastructure as Code for the gitraf ecosystem.

## Structure

```
gitraf-infra/
├── kubernetes/           # Kubernetes manifests (Kustomize)
│   ├── base/            # Master kustomization (deploys everything)
│   ├── gitraf-server/   # Web UI and API server
│   ├── gitraf-core/     # Git HTTP backend (ogit)
│   ├── nginx/           # Reverse proxy with SSL
│   ├── backup/          # Backup CronJob
│   └── gitraf-pages/    # Static site hosting
├── scripts/             # Installation and helper scripts
└── terraform/           # Hetzner resource management (optional)
```

## Prerequisites

- **k3s** or any Kubernetes cluster
- **Tailscale** (optional, for private access)
- **Let's Encrypt certificates** for your domain
- **Docker images** built and imported into your cluster

## Quick Start

### 1. Install k3s (if not already installed)

```bash
# Run the install script
./scripts/install-k3s.sh
```

### 2. Build and import Docker images

```bash
# Build gitraf-server
cd /path/to/gitraf-server
docker build -t gitraf-server:latest .
k3s ctr images import <(docker save gitraf-server:latest)

# Build ogit
cd /path/to/ogit
docker build -t ogit:latest .
k3s ctr images import <(docker save ogit:latest)
```

### 3. Configure your deployment

Edit the following files to replace placeholders with your values:

**`kubernetes/gitraf-server/configmap.yaml`:**
- `GITRAF_PUBLIC_URL`: Your public git server URL (e.g., `https://git.example.com`)
- `GITRAF_TAILNET_URL`: Your Tailscale machine name (e.g., `my-server.tail12345.ts.net`)
- `GITRAF_PAGES_BASE_URL`: Your pages domain (e.g., `example.com`)

**`kubernetes/nginx/configmap.yaml`:**
- Replace `PUBLIC_IP` with your server's public IP
- Replace `DOMAIN` with your git server domain
- Replace `PAGES_DOMAIN` with your pages base domain
- Update SSL certificate paths to match your Let's Encrypt setup

### 4. Create required directories on the host

```bash
sudo mkdir -p /opt/ogit/data/repos
sudo mkdir -p /opt/ogit/pages
sudo mkdir -p /opt/gitraf-server/static
sudo mkdir -p /var/www/certbot

# Set permissions (adjust user as needed)
sudo chown -R 1000:1000 /opt/ogit
sudo chown -R 1000:1000 /opt/gitraf-server
```

### 5. Deploy

```bash
# Deploy all components
kubectl apply -k kubernetes/base/

# Or deploy individual components
kubectl apply -k kubernetes/gitraf-server/
kubectl apply -k kubernetes/gitraf-core/
kubectl apply -k kubernetes/nginx/
```

### 6. Configure Tailscale Serve (optional)

For HTTPS access via Tailscale on standard port 443:

```bash
tailscale serve --bg http://127.0.0.1:8081
```

## Components

### gitraf-server
- **Purpose**: Web UI, repository browser, settings management
- **Ports**: 8081 (HTTP), 8443 (HTTPS/TLS)
- **Access**: Public (via nginx) and Tailscale

### ogit (gitraf-core)
- **Purpose**: Git HTTP backend for clone/push operations
- **Port**: 30081 (NodePort)
- **Access**: Via nginx reverse proxy

### nginx
- **Purpose**: SSL termination, routing, pages hosting
- **Ports**: 80, 443 (bound to public IP)
- **Features**: Git LFS support, wildcard pages hosting

## Tailscale Integration

gitraf-server automatically detects Tailscale clients (100.64.0.0/10 range) and enables:
- Push access (blocked for public internet)
- Admin settings access
- Server update functionality

## Troubleshooting

### Check pod status
```bash
kubectl get pods -n gitraf
```

### View logs
```bash
kubectl logs -n gitraf deployment/gitraf-server
kubectl logs -n gitraf deployment/ogit
kubectl logs -n gitraf deployment/nginx
```

### Restart a deployment
```bash
kubectl rollout restart deployment/gitraf-server -n gitraf
```

## Customization

Use Kustomize overlays for environment-specific configurations:

```bash
# Create an overlay
mkdir -p kubernetes/overlays/production
cat > kubernetes/overlays/production/kustomization.yaml << EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../base
patchesStrategicMerge:
  - configmap-patch.yaml
EOF
```
