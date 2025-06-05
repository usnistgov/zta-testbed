#!/bin/bash

. env-istio.sh

#load helloworld and sleep images

echo "Pulling images to a docker host..."
docker pull docker.io/istio/examples-helloworld-v1
docker pull docker.io/istio/examples-helloworld-v2
docker pull docker.io/kong/httpbin
docker pull curlimages/curl

echo "Install demo apps to kind clusters..."
kubectl --context="${CLUSTER1_CTX}" label ns default istio-injection=enabled --overwrite
kubectl --context="${CLUSTER1_CTX}" apply -f https://raw.githubusercontent.com/istio/istio/master/samples/sleep/sleep.yaml
kubectl --context="${CLUSTER1_CTX}" apply -f https://raw.githubusercontent.com/istio/istio/master/samples/helloworld/helloworld.yaml -l service=helloworld
kubectl --context="${CLUSTER1_CTX}" apply -f https://raw.githubusercontent.com/istio/istio/master/samples/helloworld/helloworld.yaml -l version=v1


kubectl --context="${CLUSTER2_CTX}" label ns default istio-injection=enabled --overwrite
kubectl --context="${CLUSTER2_CTX}" apply -f https://raw.githubusercontent.com/istio/istio/master/samples/sleep/sleep.yaml
kubectl --context="${CLUSTER2_CTX}" apply -f https://raw.githubusercontent.com/istio/istio/master/samples/helloworld/helloworld.yaml -l service=helloworld
kubectl --context="${CLUSTER2_CTX}" apply -f https://raw.githubusercontent.com/istio/istio/master/samples/helloworld/helloworld.yaml -l version=v2
