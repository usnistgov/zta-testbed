#!/bin/sh
set -x

curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.24.3 sh -
cd istio-1.24.3
sudo install -m 0755 bin/istioctl /usr/local/bin/istioctl


# install the latest version
#ISTIO_VERSION="$(curl -sL https://github.com/istio/istio/releases | \
#                grep -o 'releases/[0-9]*.[0-9]*.[0-9]*/' | sort -V | \
#                tail -1 | awk -F'/' '{ print $2}')"
#curl -L https://istio.io/downloadIstio | sh -
#cd istio-$ISTIO_VERSION
#sudo install -m 0755 bin/istioctl /usr/local/bin/istioctl
