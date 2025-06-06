
Istio Multi Cluster on different networks
==========================================
(https://istio.io/latest/docs/setup/install/multicluster/multi-primary_multi-network/)

 -- "different networks" means there is no direct connectivity between pods across cluster boundaries.




1. install cilium, isitoctl, kubectl, k8s, k9s

  (1) base directory = config_and_diff_patch/kubernetes_helm/istio-multicluster-script

  (2) install each application
      install_cilium.sh
      install_istioctl.sh
      install_k9s_webi.sh
      install_kubectl.sh



  (3) install kubernetes with kubeadm

      3-bootstrap-kube-install-istio-setup.sh

     -- in case of single controll node without worker nodes,
          Don't forget to remote taint
          kubectl taint nodes --all node-role.kubernetes.io/control-plane-


  (4) install CNI with cilium, 5-helm_install_cilium.sh




2. install LoadBalancer, Metallb

  (1) install LoabBalancer
  
    6-install_metallb_istio.sh

  (2) in IPAddressPool,
      IP address range should be the same as the interface that the host currently has.
      Otherwise, multi clustering NOT working !!!

  (3) check if the LoadBalancer is working correctly

      kubectl create deployment nginx --image=nginx
      kubectl expose deployment nginx --name=svc-nginx --type=LoadBalancer --port=80

      then,
      curl 10.5.0.121 <<-- from the current host and another host at the same segment to confirm to access



3. Optional scripts

  7-iptables-forwarding-istio-cilium
  8-setup-clustermesh


