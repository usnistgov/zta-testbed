#!/bin/sh
set -x

. /vagrant/env-istio.sh 

# download docker images to a host
echo "Pulling metallb images to a docker host..."
#docker pull quay.io/metallb/controller:v0.13.10
#docker pull quay.io/metallb/speaker:v0.13.10



# Install metallb using the latest version 13.10
echo "install metallb on $CLUSTER1_NAME..."
kubectl apply --context="${CLUSTER1_CTX}" -f https://raw.githubusercontent.com/metallb/metallb/v0.13.10/config/manifests/metallb-native.yaml

echo "install metallb on $CLUSTER2_NAME..."
kubectl apply --context="${CLUSTER2_CTX}" -f https://raw.githubusercontent.com/metallb/metallb/v0.13.10/config/manifests/metallb-native.yaml



# wait for metallb to get ready
echo "Wait 30 sec for metallb to get ready..."

sleep 30

#create metallb pool and L2 advertisment
echo "creating metallb l2 pool on $CLUSTER1_NAME..."
kubectl apply --context="${CLUSTER1_CTX}" -f - <<EOF
---
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: lb-pool
  namespace: metallb-system
spec:
  addresses:
  - 10.5.0.100-10.5.0.120 
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: lb-adv
  namespace: metallb-system
EOF



echo "creating metallb l2 pool on $CLUSTER2_NAME..."
kubectl apply --context="${CLUSTER2_CTX}" -f - <<EOF
---
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: kind-pool
  namespace: metallb-system
spec:
  addresses:
  - 10.5.0.121-10.5.0.139 
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: all-pools
  namespace: metallb-system
EOF
