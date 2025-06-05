#!/bin/sh
set -x

. env-istio.sh 

docker pull quay.io/cilium/cilium:v1.14.1

echo "Adding cilium helm repo..."
helm repo add cilium https://helm.cilium.io/


# install cilium
echo "Installing cilium in $CLUSTER1_NAME..."
helm upgrade --install cilium cilium/cilium --version 1.14.1 --kube-context $CLUSTER1_CTX \
   --namespace kube-system \
   --set cluster.name=cluster1 \
   --set cluster.id=1 \
   --set operator.replicas=1 \
   --set image.pullPolicy=IfNotPresent \
   --set ipam.mode=kubernetes \
   --set bgpControlPlane.enabled=true



echo "Installing cilium in $CLUSTER2_NAME..."
helm upgrade --install cilium cilium/cilium --version 1.14.1 --kube-context $CLUSTER2_CTX \
   --namespace kube-system \
   --set cluster.name=cluster2 \
   --set cluster.id=2 \
   --set operator.replicas=1 \
   --set image.pullPolicy=IfNotPresent \
   --set ipam.mode=kubernetes \
   --set bgpControlPlane.enabled=true
