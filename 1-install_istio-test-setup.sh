#!/bin/sh
set -x

PWD=$(pwd)
install_kubectl.sh
install_istioctl.sh 
install_cilium.sh 
install_k9s_webi.sh 


