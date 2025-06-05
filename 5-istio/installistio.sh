#!/bin/bash

LOC="$PWD"
. ../env-istio.sh

# download istio images to a host
echo "Pulling istio images to a docker host..."
docker pull $HUB/pilot:$TAG
docker pull $HUB/proxyv2:$TAG



# install certs in both clusters
kubectl create namespace istio-system --context=${CLUSTER1_CTX}
kubectl create secret generic cacerts -n istio-system \
      --from-file=${LOC}certs/cluster1/ca-cert.pem \
      --from-file=${LOC}certs/cluster1/ca-key.pem \
      --from-file=${LOC}certs/cluster1/root-cert.pem \
      --from-file=${LOC}certs/cluster1/cert-chain.pem \
      --context=${CLUSTER1_CTX}

kubectl create namespace istio-system --context=${CLUSTER2_CTX}
kubectl create secret generic cacerts -n istio-system \
      --from-file=${LOC}certs/cluster2/ca-cert.pem \
      --from-file=${LOC}certs/cluster2/ca-key.pem \
      --from-file=${LOC}certs/cluster2/root-cert.pem \
      --from-file=${LOC}certs/cluster2/cert-chain.pem \
      --context=${CLUSTER2_CTX}

# Install istio iop profile on cluster5
echo "Installing istio in $CLUSTER1_NAME..."
istioctl --context="${CLUSTER1_CTX}" install -f ${LOC}cluster1.yaml --skip-confirmation

# Install istio profile on cluster6
echo "Installing istio in $CLUSTER2_NAME..."
istioctl --context="${CLUSTER2_CTX}" install -f ${LOC}cluster2.yaml --skip-confirmation

## fetch cluster2 controlplan address
#SERVER_CLU2=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' clu2-control-plane)

# Enable Endpoint Discovery
echo "Enable Endpoint Discovery..."
istioctl create-remote-secret \
    --context="${CLUSTER2_CTX}" \
    --name=cluster2 | \
    kubectl apply -f - --context="${CLUSTER1_CTX}"

istioctl create-remote-secret \
    --context="${CLUSTER1_CTX}" \
    --name=cluter1 | \
    kubectl apply -f - --context="${CLUSTER2_CTX}"
