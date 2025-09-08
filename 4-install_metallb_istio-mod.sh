#!/bin/bash
set -x

PWD=$(pwd)
. $PWD/env-istio.sh

# download docker images to a host
echo "Pulling metallb images to a docker host..."
#docker pull quay.io/metallb/controller:v0.13.10
#docker pull quay.io/metallb/speaker:v0.13.10

INPUT_IP_ADDRESS="${1:-}"     # 빈 값이면 ip route 로 탐지

if [[ -n "$INPUT_IP_ADDRESS" ]]; then
  # ip address format verification
  if [[ ! "$INPUT_IP_ADDRESS" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    echo "ERROR: INPUT_IP_ADDRESS format is NOT IPv4 : $INPUT_IP_ADDRESS" >&2
    exit 1
  fi
  ADV_IP="$INPUT_IP_ADDRESS"
else
  ADV_IP=$(ip route get 1.1.1.1 | awk '{for(i=1;i<=NF;i++){if($i=="src"){print $(i+1); exit}}}')
fi

# extract first three octet (xxx.xxx.xxx)
PREFIX3=$(echo "$ADV_IP" | awk -F. '{print $1"."$2"."$3}')

# check 
echo "Detected IP: $ADV_IP"
echo "Using prefix: $PREFIX3"



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
  - ${PREFIX3}.100-${PREFIX3}.119 
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
  - ${PREFIX3}.120-${PREFIX3}.139 
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: all-pools
  namespace: metallb-system
EOF
