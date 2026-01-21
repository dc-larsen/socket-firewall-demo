#!/bin/bash
# Cleanup Socket Firewall Demo

NAMESPACE="socket-firewall-demo"

echo "Cleaning up Socket Firewall Demo..."

# Kill port-forward
pkill -f "kubectl port-forward.*socket-firewall" 2>/dev/null || true

# Uninstall helm release
helm uninstall socket-firewall -n $NAMESPACE 2>/dev/null || true

# Delete namespace
kubectl delete namespace $NAMESPACE 2>/dev/null || true

# Remove cloned chart
rm -rf /tmp/socket-firewall-helm 2>/dev/null || true

echo "Cleanup complete"
