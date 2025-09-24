#!/bin/bash
set -x

LOC="$PWD"
. ../env-istio.sh

# download istio images to a host
#echo "Pulling istio images to a docker host..."
#docker pull $HUB/pilot:$TAG
#docker pull $HUB/proxyv2:$TAG



# install certs in both clusters
kubectl create namespace istio-system --context=${CLUSTER1_CTX}
kubectl create secret generic cacerts -n istio-system \
      --from-file=${LOC}/certs/cluster1/ca-cert.pem \
      --from-file=${LOC}/certs/cluster1/ca-key.pem \
      --from-file=${LOC}/certs/cluster1/root-cert.pem \
      --from-file=${LOC}/certs/cluster1/cert-chain.pem \
      --context=${CLUSTER1_CTX}

kubectl create namespace istio-system --context=${CLUSTER2_CTX}
kubectl create secret generic cacerts -n istio-system \
      --from-file=${LOC}/certs/cluster2/ca-cert.pem \
      --from-file=${LOC}/certs/cluster2/ca-key.pem \
      --from-file=${LOC}/certs/cluster2/root-cert.pem \
      --from-file=${LOC}/certs/cluster2/cert-chain.pem \
      --context=${CLUSTER2_CTX}


# Set the default network for cluster1,2
kubectl --context="${CTX_CLUSTER1}" get namespace istio-system && \                                
kubectl --context="${CTX_CLUSTER1}" label namespace istio-system topology.istio.io/network=network1
kubectl --context="${CTX_CLUSTER2}" get namespace istio-system && \
kubectl --context="${CTX_CLUSTER2}" label namespace istio-system topology.istio.io/network=network2





# Configure cluster1 as a primary
echo "Installing istio in $CLUSTER1_NAME..."
istioctl --context="${CLUSTER1_CTX}" install -f ${LOC}/cluster1-SPIRE-trustDomain.yaml --skip-confirmation

# Configure cluster2 as a primary
echo "Installing istio in $CLUSTER2_NAME..."
istioctl --context="${CLUSTER2_CTX}" install -f ${LOC}/cluster2-SPIRE-trustDomain.yaml --skip-confirmation


exit 1

# Install the east-west gateway in cluster1
#  (cf.)  samples/multicluster/gen-eastwest-gateway.sh --network network1 
#
#istioctl --context="${CTX_CLUSTER1}" install -y -f - <<EOF
#apiVersion: install.istio.io/v1alpha1
#kind: IstioOperator
#metadata:
#  name: eastwest
#spec:
#  revision: ""
#  profile: empty
#  components:
#    ingressGateways:
#      - name: istio-eastwestgateway
#        label:
#          istio: eastwestgateway
#          app: istio-eastwestgateway
#          topology.istio.io/network: network1
#        enabled: true
#        k8s:
#          env:
#            # traffic through this gateway should be routed inside the network
#            - name: ISTIO_META_REQUESTED_NETWORK_VIEW
#              value: network1
#          service:
#            ports:
#              - name: status-port
#                port: 15021
#                targetPort: 15021
#              - name: tls
#                port: 15443
#                targetPort: 15443
#              - name: tls-istiod
#                port: 15012
#                targetPort: 15012
#              - name: tls-webhook
#                port: 15017
#                targetPort: 15017
#  values:
#    gateways:
#      istio-ingressgateway:
#        injectionTemplate: gateway
#    global:
#      network: network1
#EOF

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





# Install the east-west gateway in cluster2
#  (cf.)  samples/multicluster/gen-eastwest-gateway.sh --network network2 
#
#istioctl --context="${CTX_CLUSTER2}" install -y -f - <<EOF
#apiVersion: install.istio.io/v1alpha1
#kind: IstioOperator
#metadata:
#  name: eastwest
#spec:
#  revision: ""
#  profile: empty
#  components:
#    ingressGateways:
#      - name: istio-eastwestgateway
#        label:
#          istio: eastwestgateway
#          app: istio-eastwestgateway
#          topology.istio.io/network: network2
#        enabled: true
#        k8s:
#          env:
#            # traffic through this gateway should be routed inside the network
#            - name: ISTIO_META_REQUESTED_NETWORK_VIEW
#              value: network2
#          service:
#            ports:
#              - name: status-port
#                port: 15021
#                targetPort: 15021
#              - name: tls
#                port: 15443
#                targetPort: 15443
#              - name: tls-istiod
#                port: 15012
#                targetPort: 15012
#              - name: tls-webhook
#                port: 15017
#                targetPort: 15017
#  values:
#    gateways:
#      istio-ingressgateway:
#        injectionTemplate: gateway
#    global:
#      network: network2
#EOF

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



