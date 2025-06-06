#!/bin/bash

. ../env-istio.sh


echo "*************************"

echo "$CLUSTER1_NAME worker nodes..."
kubectl --context="${CLUSTER1_CTX}" get nodes -o custom-columns=NAME:.metadata.name,IP:.status.addresses[0].address

echo "*************************"


# Send one request from the curl pod on cluster1 to the HelloWorld service:
# Repeat this request several times and verify that the HelloWorld version should toggle between v1 and v2:
for i in {1..10}; do  
kubectl exec --context="${CTX_CLUSTER1}" -n sample -c curl \
    "$(kubectl get pod --context="${CTX_CLUSTER1}" -n sample -l \
    app=curl -o jsonpath='{.items[0].metadata.name}')" \
    -- curl -sS helloworld.sample:5000/hello; sleep 1; done




