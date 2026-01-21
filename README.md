# Socket Firewall Demo

Demonstrates Socket.dev Registry Firewall blocking vulnerable packages in Kubernetes.

## What This Demo Shows

The Socket Firewall intercepts package downloads and blocks packages with known vulnerabilities. This demo:

1. Deploys the Socket Firewall using the [Helm chart](https://github.com/dc-larsen/socket-firewall-helm)
2. Attempts to install `form-data@2.3.3` (known prototype pollution vulnerability)
3. Verifies the package is **blocked** by the firewall
4. Confirms safe packages like `lodash@4.17.21` still install successfully

## Prerequisites

- Kubernetes cluster (Orbstack, minikube, kind, etc.)
- Helm 3.8+
- Socket.dev API token with Firewall permissions

## Quick Start

```bash
# Set your Socket API token
export SOCKET_SECURITY_API_TOKEN="your-token"

# Run the demo
./demo.sh
```

## What Happens

```
1. Deploy Socket Firewall (via Helm chart)
2. Configure npm to use firewall proxy
3. Attempt: npm install form-data@2.3.3
   → BLOCKED (403 Forbidden - Security Policy)
4. Attempt: npm install lodash@4.17.21
   → SUCCESS (package is safe)
```

## Expected Output

```
[BLOCKED] form-data@2.3.3
  npm error 403 Forbidden - Blocked by Socket Security Policy

[ALLOWED] lodash@4.17.21
  added 1 package in 2s
```

## Manual Testing

```bash
# Port forward to the firewall
kubectl port-forward svc/socket-firewall 8443:443 &

# Test blocked package
curl -k https://npm.firewall.local:8443/form-data/-/form-data-2.3.3.tgz
# Returns: 403 with blocking message

# Test safe package
curl -k https://npm.firewall.local:8443/lodash/-/lodash-4.17.21.tgz
# Returns: 200 with tarball
```

## Cleanup

```bash
./cleanup.sh
```

## Resources

- [Socket Firewall Helm Chart](https://github.com/dc-larsen/socket-firewall-helm)
- [Socket Firewall Source](https://github.com/SocketDev/socket-nginx-firewall)
- [Socket.dev](https://socket.dev)
