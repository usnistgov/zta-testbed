#!/bin/sh
set -x

PWD=$(pwd)
$PWD/install_kubectl.sh
$PWD/install_istioctl.sh
$PWD/install_cilium.sh
$PWD/install_k9s_webi.sh


