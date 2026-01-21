#!/bin/bash
# Socket Firewall Demo - Demonstrates blocking of vulnerable packages
set -e

NAMESPACE="socket-firewall-demo"
HELM_CHART="https://github.com/dc-larsen/socket-firewall-helm"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo_step() { echo -e "\n${BLUE}==>${NC} $1"; }
echo_success() { echo -e "${GREEN}✓${NC} $1"; }
echo_blocked() { echo -e "${RED}✗ BLOCKED:${NC} $1"; }
echo_warn() { echo -e "${YELLOW}!${NC} $1"; }

# Check prerequisites
check_prereqs() {
    echo_step "Checking prerequisites..."

    if [ -z "$SOCKET_SECURITY_API_TOKEN" ]; then
        echo_warn "SOCKET_SECURITY_API_TOKEN not set"
        echo "Set it with: export SOCKET_SECURITY_API_TOKEN=your-token"
        exit 1
    fi

    command -v kubectl >/dev/null || { echo "kubectl required"; exit 1; }
    command -v helm >/dev/null || { echo "helm required"; exit 1; }
    command -v npm >/dev/null || { echo "npm required"; exit 1; }

    kubectl cluster-info >/dev/null 2>&1 || { echo "Kubernetes cluster not available"; exit 1; }

    echo_success "All prerequisites met"
}

# Deploy the firewall
deploy_firewall() {
    echo_step "Deploying Socket Firewall..."

    # Create namespace
    kubectl create namespace $NAMESPACE 2>/dev/null || true

    # Clone helm chart if not exists
    if [ ! -d "/tmp/socket-firewall-helm" ]; then
        git clone --depth 1 $HELM_CHART /tmp/socket-firewall-helm 2>/dev/null
    fi

    # Install chart
    helm upgrade --install socket-firewall /tmp/socket-firewall-helm \
        --namespace $NAMESPACE \
        --set socket.apiToken="$SOCKET_SECURITY_API_TOKEN" \
        --set registries.npm.domains[0]=npm.firewall.local \
        --wait --timeout 120s

    echo_success "Firewall deployed"
}

# Setup port forwarding
setup_access() {
    echo_step "Setting up access..."

    # Kill existing port-forward
    pkill -f "kubectl port-forward.*socket-firewall" 2>/dev/null || true
    sleep 1

    # Start port forward
    kubectl port-forward svc/socket-firewall 8443:443 -n $NAMESPACE &
    sleep 3

    # Add hosts entry if needed
    if ! grep -q "npm.firewall.local" /etc/hosts 2>/dev/null; then
        echo_warn "Add this to /etc/hosts: 127.0.0.1 npm.firewall.local"
    fi

    echo_success "Port forward running on localhost:8443"
}

# Test blocking
test_blocking() {
    echo_step "Testing package blocking..."

    TEST_DIR=$(mktemp -d)
    cd "$TEST_DIR"
    npm init -y >/dev/null 2>&1

    cat > .npmrc << 'EOF'
registry=https://npm.firewall.local:8443/
strict-ssl=false
EOF

    echo ""
    echo "Attempting to install form-data@2.3.3 (vulnerable)..."
    echo ""

    if npm install form-data@2.3.3 2>&1; then
        echo_warn "Package was NOT blocked (check API token permissions)"
    else
        echo_blocked "form-data@2.3.3 - Blocked by Socket Security Policy"
    fi

    echo ""
    echo "Attempting to install lodash@4.17.21 (safe)..."
    echo ""

    if npm install lodash@4.17.21 2>&1; then
        echo_success "lodash@4.17.21 installed successfully"
    else
        echo_warn "Safe package failed (may be network/cert issue)"
    fi

    cd - >/dev/null
    rm -rf "$TEST_DIR"
}

# Show logs
show_logs() {
    echo_step "Firewall logs (last 10 lines):"
    kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=socket-firewall --tail=10 2>/dev/null | grep -v "health\|kube-probe" || true
}

# Main
main() {
    echo "╔════════════════════════════════════════╗"
    echo "║     Socket Firewall Demo               ║"
    echo "║     Blocking Vulnerable Packages       ║"
    echo "╚════════════════════════════════════════╝"

    check_prereqs
    deploy_firewall
    setup_access
    test_blocking
    show_logs

    echo ""
    echo_step "Demo complete!"
    echo "  Run ./cleanup.sh when done"
}

main "$@"
