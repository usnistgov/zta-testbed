#!/bin/bash
set -x

LOC="$PWD"
. ../env-istio.sh


# Expose services in cluster1
kubectl --context="${CTX_CLUSTER1}" apply -n istio-system -f - <<EOF
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: cross-network-gateway
spec:
  selector:
    istio: eastwestgateway
  servers:
    - port:
        number: 15443
        name: tls
        protocol: TLS
      tls:
        mode: AUTO_PASSTHROUGH
      hosts:
        - "*.local"
EOF






# Expose services in cluster1
kubectl --context="${CTX_CLUSTER2}" apply -n istio-system -f - <<EOF
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: cross-network-gateway
spec:
  selector:
    istio: eastwestgateway
  servers:
    - port:
        number: 15443
        name: tls
        protocol: TLS
      tls:
        mode: AUTO_PASSTHROUGH
      hosts:
        - "*.local"
EOF






## fetch cluster2 controlplan address
#SERVER_CLU2=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' clu2-control-plane)

# Enable Endpoint Discovery
echo "Enable Endpoint Discovery..."
# Install a remote secret in cluster2 that provides access to cluster1’s API server.
istioctl create-remote-secret \
    --context="${CTX_CLUSTER1}" \
    --name=cluster1 | \
    kubectl apply -f - --context="${CTX_CLUSTER2}"

# Install a remote secret in cluster1 that provides access to cluster2’s API server.
istioctl create-remote-secret \
    --context="${CTX_CLUSTER2}" \
    --name=cluster2 | \
    kubectl apply -f - --context="${CTX_CLUSTER1}"



