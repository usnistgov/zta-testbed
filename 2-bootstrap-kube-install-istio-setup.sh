#!/usr/bin/env bash
set -euo pipefail
set -x

# Kubernetes Bootstrapping Script
# Tested on Ubuntu 22.04 - May need tweaking for other versions

# Configuration
KUBERNETES_VERSION="1.31"
CALICO_VERSION="3.28.2"
POD_NETWORK_CIDR="192.168.0.0/16"
ROOT_PASSWORD="kubeadmin"

ADV_IP=$(ip route get 1.1.1.1 | awk '{for(i=1;i<=NF;i++){if($i=="src"){print $(i+1); exit}}}')
LAST_OCTET=$(echo "$ADV_IP" | awk -F. '{print $4}')

# default value = even / odd number
if (( LAST_OCTET % 2 == 0 )); then
  DEFAULT_CLUSTER="cluster1"
else
  DEFAULT_CLUSTER="cluster2"
fi

# if there is input string for cluster name, then use it 
CLUSTER_NAME="${1:-$DEFAULT_CLUSTER}"

echo "Detected IP: $ADV_IP"
echo "Last octet: $LAST_OCTET"
echo "Cluster name: $CLUSTER_NAME"


cat <<EOF >/root/config.yaml
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: ${ADV_IP}
  bindPort : 6443
---
apiVersion: kubeadm.k8s.io/v1beta3
kubernetesVersion: v1.29.1
kind: ClusterConfiguration
metadata:
  name: ${CLUSTER_NAME}
networking:
  dnsDomain: cluster.local
  podSubnet: ${POD_NETWORK_CIDR}
  serviceSubnet: 10.96.0.0/12
EOF



# -------------------------------------------------------------------
# kubeadm 1.31.8 matches to apiVersion: v1beta4
# clusterName can only be changed with the init config script
#
cat <<EOF >/root/init-config.yaml
apiVersion: kubeadm.k8s.io/v1beta4
kind: ClusterConfiguration
clusterName: ${CLUSTER_NAME}  
kubernetesVersion: v${KUBERNETES_VERSION}  
controlPlaneEndpoint: "${ADV_IP}:6443"
networking:
  podSubnet: ${POD_NETWORK_CIDR}  
  serviceSubnet: 10.96.0.0/12
apiServer:
  extraArgs:
    advertise-address: ${ADV_IP} 
EOF
# 
# c.f. context name only can be changed by kubectl command
#   kubectl config rename-context kubernetes-admin@cluster1 cluster1
# -------------------------------------------------------------------



log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

handle_error() {
    log "Error on line $1"
    exit 1
}

trap 'handle_error $LINENO' ERR

install_packages() {
    local packages=("$@")
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -qq -y "${packages[@]}"
}

main_tasks() {
    log "TASK 1: Installing essential packages"
    install_packages net-tools curl ssh software-properties-common gpg

	# packet forwarding enabled in kernel
	echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward
	sudo sysctl -w net.ipv4.ip_forward=1

    log "TASK 2: Installing containerd runtime"
    install_packages apt-transport-https ca-certificates curl gnupg lsb-release

    mkdir -p /etc/apt/keyrings
    #curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    #echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list

    #install_packages containerd.io
    command -v containerd >/dev/null 2>&1 || (apt update && apt install -y containerd)
    mkdir -p /etc/containerd/
    containerd config default > /etc/containerd/config.toml
    sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml
    systemctl restart containerd
    systemctl enable containerd

    log "TASK 3: Setting up Kubernetes repo"
    # ref: https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v${KUBERNETES_VERSION}/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${KUBERNETES_VERSION}/deb/ /" > /etc/apt/sources.list.d/kubernetes.list

    log "TASK 4: Installing Kubernetes components"
    install_packages kubeadm kubelet kubectl
    sudo apt-mark hold kubelet kubeadm kubectl
    echo 'KUBELET_EXTRA_ARGS="--fail-swap-on=false"' > /etc/default/kubelet
    systemctl restart kubelet

    log "TASK 5: Enabling SSH password authentication -- skip"
    #sed -i 's/PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config /etc/ssh/sshd_config.d/*
    #echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config
    #systemctl reload sshd

    log "TASK 6: Setting root password --skip"
    #echo "root:${ROOT_PASSWORD}" | chpasswd
    #echo "export TERM=xterm" >> /etc/bash.bashrc
}

# Master node specific tasks
master_tasks() {
    log "TASK 7: Pulling required containers"
    kubeadm config images pull

    log "TASK 8: Initializing Kubernetes Cluster"


    #kubeadm init --config /root/init-config.yaml
    #kubeadm init --pod-network-cidr="${POD_NETWORK_CIDR}" --apiserver-advertise-address=${ADV_IP} --ignore-preflight-errors=all >> /root/kubeinit.log 2>&1     # <-- in case of LXC
    kubeadm init --pod-network-cidr="${POD_NETWORK_CIDR}" --apiserver-advertise-address=${ADV_IP} >> /root/kubeinit.log 2>&1

    log "TASK 9: Copying kube admin config"
    mkdir -p /root/.kube
    cp /etc/kubernetes/admin.conf /root/.kube/config

    log "TASK 10: Deploying Calico network -- skip"
    #kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v${CALICO_VERSION}/manifests/tigera-operator.yaml
    #kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v${CALICO_VERSION}/manifests/custom-resources.yaml

    log "TASK 11: Generating cluster join command"
    joinCommand=$(kubeadm token create --print-join-command 2>/dev/null)
    echo "$joinCommand --ignore-preflight-errors=all" > /joincluster.sh
    chmod +x /joincluster.sh

    log "TASK etc: taint setting"
    kubectl taint nodes --all node-role.kubernetes.io/control-plane-
}

# Worker node specific tasks
worker_tasks() {
    log "TASK 7: Joining node to Kubernetes Cluster"
    install_packages sshpass
    sshpass -p "${ROOT_PASSWORD}" scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no kmaster.lxd:/joincluster.sh /joincluster.sh
    bash /joincluster.sh >> /tmp/joincluster.log 2>&1
}

main() {
    main_tasks

    #if [[ $(hostname) =~ .*master.* ]]; then
    #if [[ $(hostname) =~ .*comp.* ]]; then
    #    master_tasks
    if [[ $(hostname) =~ .*worker.* ]]; then
        worker_tasks
    else
        master_tasks
    fi

    log "Rename Context"
    kubectl config rename-context kubernetes-admin@kubernetes ${CLUSTER_NAME}

    log "Bootstrap completed successfully"
}

main
