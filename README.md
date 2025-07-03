

Istio Multi Cluster on different networks 
==========================================

 -- "different networks" means there is no direct connectivity between pods across cluster boundaries.




1. install cilium, isitoctl, kubectl, k8s, k9s 

 Use the script, 1-install_istio-test-setup.sh, to install following applications,
 
    install_cilium.sh
    install_istioctl.sh
    install_k9s_webi.sh
    install_kubectl.sh



2. Install kubernetes with kubeadm

	  2-bootstrap-kube-install-istio-setup-comp2.sh

   -- in case of single controll node without worker nodes, 
        Don't forget to remote taint 
        kubectl taint nodes --all node-role.kubernetes.io/control-plane-


3. Install CNI with Cilium, 3-helm_install_cilium_mod-comp2.sh 
    -- Cilium CNI is good choice to use for eBPF security functions in Kubernetes cluster 



4. Install LoadBalancer, Metallb, with 4-install_metallb_istio-mod-comp2.sh

(1) in IPAddressPool, 
    IP address range should be the same as the interface that the host currently has.
    Otherwise, multi clustering NOT working !!!

(2) check if the LoadBalancer is working correctly
    
    kubectl create deployment nginx --image=nginx
    kubectl expose deployment nginx --name=svc-nginx --type=LoadBalancer --port=80

    then, 
    curl 10.5.0.121 <<-- from the current host and another host at the same segment to confirm to access






------------------------------------------------------
 Istio Setup 
    Plug in CA Certificates and key into the cluster
------------------------------------------------------


** pre-requisite -- download istio source

    curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.24.3 sh - 
    cd istio-1.24.3                                                    
    sudo install -m 0755 bin/istioctl /usr/local/bin/istioctl          


-- Configure Trust
    A multicluster service mesh deployment requires that you establish trust between all clusters in the mesh. 
    Depending on the requirements for your system, there may be multiple options available for establishing trust. 



  (1) In the top-level directory of the Istio installation package, create a directory to hold certificates and keys:
    $ mkdir -p certs
    $ pushd certs


  (2) Generate the root certificate and key:
    $ make -f ../tools/certs/Makefile.selfsigned.mk root-ca

      This will generate the following files:

      root-cert.pem: the generated root certificate
      root-key.pem: the generated root key
      root-ca.conf: the configuration for openssl to generate the root certificate
      root-cert.csr: the generated CSR for the root certificate


  (3) For each cluster, generate an intermediate certificate and key for the Istio CA. The following is an example for cluster1:
    $ make -f ../tools/certs/Makefile.selfsigned.mk cluster1-cacerts

      This will generate the following files in a directory named cluster1:

      ca-cert.pem: the generated intermediate certificates
      ca-key.pem: the generated intermediate key
      cert-chain.pem: the generated certificate chain which is used by istiod
      root-cert.pem: the root certificate


      You can replace cluster1 with a string of your choosing. For example, with the argument cluster2-cacerts, 
      you can create certificates and key in a directory called cluster2.

      If you are doing this on an offline machine, copy the generated directory to a machine with access to the clusters.



  (4) In each cluster, create a secret cacerts including all the input files ca-cert.pem, ca-key.pem, root-cert.pem and cert-chain.pem. For example, for cluster1:
    $ kubectl create namespace istio-system
    $ kubectl create secret generic cacerts -n istio-system \
          --from-file=cluster1/ca-cert.pem \
          --from-file=cluster1/ca-key.pem \
          --from-file=cluster1/root-cert.pem \
          --from-file=cluster1/cert-chain.pem

  (5) Return to the top-level directory of the Istio installation:
    $ popd






--------------------------------------------------
 Istio Setup
    Install Multi-Primary on different networks
--------------------------------------------------


(1) Set the default network for cluster1
    If the istio-system namespace is already created, we need to set the cluster’s network there

    kubectl --context="${CTX_CLUSTER1}" get namespace istio-system && \
    kubectl --context="${CTX_CLUSTER1}" label namespace istio-system topology.istio.io/network=network1


(2) Configure cluster1 as a primary


    $ cat <<EOF > cluster1.yaml
    apiVersion: install.istio.io/v1alpha1
    kind: IstioOperator
    spec:
      values:
        global:
          meshID: mesh1
          multiCluster:
            clusterName: cluster1
          network: network1
    EOF

   $ istioctl install --context="${CTX_CLUSTER1}" -f cluster1.yaml



(3) Install the east-west gateway in cluster1

    $ samples/multicluster/gen-eastwest-gateway.sh \
        --network network1 | \
        istioctl --context="${CTX_CLUSTER1}" install -y -f -

    $ kubectl --context="${CTX_CLUSTER1}" get svc istio-eastwestgateway -n istio-system


    (c.f.) istio-1.24.3}# samples/multicluster/gen-eastwest-gateway.sh --network network1
      apiVersion: install.istio.io/v1alpha1
      kind: IstioOperator
      metadata:
        name: eastwest
      spec:
        revision: ""
        profile: empty
        components:
          ingressGateways:
            - name: istio-eastwestgateway
              label:
                istio: eastwestgateway
                app: istio-eastwestgateway
                topology.istio.io/network: network1
              enabled: true
              k8s:
                env:
                  # traffic through this gateway should be routed inside the network
                  - name: ISTIO_META_REQUESTED_NETWORK_VIEW
                    value: network1
                service:
                  ports:
                    - name: status-port
                      port: 15021
                      targetPort: 15021
                    - name: tls
                      port: 15443
                      targetPort: 15443
                    - name: tls-istiod
                      port: 15012
                      targetPort: 15012
                    - name: tls-webhook
                      port: 15017
                      targetPort: 15017
        values:
          gateways:
            istio-ingressgateway:
              injectionTemplate: gateway
          global:
            network: network1 





(4) Expose services in cluster1

    $ kubectl --context="${CTX_CLUSTER1}" apply -n istio-system -f \
        samples/multicluster/expose-services.yaml

    (cf.)
      stio-1.24.3}# cat  samples/multicluster/expose-services.yaml
      apiVersion: networking.istio.io/v1
      kind: Gateway
      metadata:
        name: cross-network-gateway
      spec:
        selector:
          istio: eastwestgateway
        servers:
          - port:
              number: 15443
              name: tls
              protocol: TLS
            tls:
              mode: AUTO_PASSTHROUGH
            hosts:
              - "*.local"



(5) Set the default network for cluster2

    $ kubectl --context="${CTX_CLUSTER2}" get namespace istio-system && \
      kubectl --context="${CTX_CLUSTER2}" label namespace istio-system topology.istio.io/network=network2


(6) Configure cluster2 as a primary


    $ cat <<EOF > cluster2.yaml
    apiVersion: install.istio.io/v1alpha1
    kind: IstioOperator
    spec:
      values:
        global:
          meshID: mesh1
          multiCluster:
            clusterName: cluster2
          network: network2
    EOF

    $ istioctl install --context="${CTX_CLUSTER2}" -f cluster2.yaml





(7) Install the east-west gateway in cluster2

    $ samples/multicluster/gen-eastwest-gateway.sh \
        --network network2 | \
        istioctl --context="${CTX_CLUSTER2}" install -y -f -

    $ kubectl --context="${CTX_CLUSTER2}" get svc istio-eastwestgateway -n istio-system





(8) Expose services in cluster2

    $ kubectl --context="${CTX_CLUSTER2}" apply -n istio-system -f \
        samples/multicluster/expose-services.yaml






(9) Enable Endpoint Discovery

    Install a remote secret in cluster2 that provides access to cluster1’s API server.
    $ istioctl create-remote-secret \
      --context="${CTX_CLUSTER1}" \
      --name=cluster1 | \
      kubectl apply -f - --context="${CTX_CLUSTER2}"


    Install a remote secret in cluster1 that provides access to cluster2’s API server.
    $ istioctl create-remote-secret \
      --context="${CTX_CLUSTER2}" \
      --name=cluster2 | \
      kubectl apply -f - --context="${CTX_CLUSTER1}"

    Congratulations! You successfully installed an Istio mesh across multiple primary clusters on different networks!




----------------------------
5. Verify the installation
----------------------------

(1) Verify Multicluster

    $ istioctl remote-clusters --context="${CTX_CLUSTER1}"
    $ istioctl remote-clusters --context="${CTX_CLUSTER2}"


    --- test logs ---
    clu1 {~/istio-1.24.3}# istioctl remote-clusters --context="${CTX_CLUSTER1}"
    NAME         SECRET                                        STATUS     ISTIOD
    cluster1                                                   synced     istiod-896cc8f4b-b4lt2
    cluster2     istio-system/istio-remote-secret-cluster2     synced     istiod-896cc8f4b-b4lt2


    clu1 {~/istio-1.24.3}# istioctl remote-clusters --context="${CTX_CLUSTER2}"
    NAME         SECRET                                        STATUS     ISTIOD
    cluster2                                                   synced     istiod-86897b9fd9-gp9ph
    cluster1     istio-system/istio-remote-secret-cluster1     synced     istiod-86897b9fd9-gp9ph




(2) Deploy the HelloWorld Service


    To begin, create the sample namespace in each cluster:
    $ kubectl create --context="${CTX_CLUSTER1}" namespace sample
    $ kubectl create --context="${CTX_CLUSTER2}" namespace sample


    Enable automatic sidecar injection for the sample namespace:
    $ kubectl label --context="${CTX_CLUSTER1}" namespace sample \
        istio-injection=enabled
    $ kubectl label --context="${CTX_CLUSTER2}" namespace sample \
        istio-injection=enabled


    Create the HelloWorld service in both clusters:
    $ kubectl apply --context="${CTX_CLUSTER1}" \
        -f samples/helloworld/helloworld.yaml \
        -l service=helloworld -n sample
    $ kubectl apply --context="${CTX_CLUSTER2}" \
        -f samples/helloworld/helloworld.yaml \
        -l service=helloworld -n sample


      (cf.) clu1 {~/istio-1.24.3}# cat samples/helloworld/helloworld.yaml
      apiVersion: v1
      kind: Service
      metadata:
        name: helloworld
        labels:
          app: helloworld
          service: helloworld
      spec:
        ports:
        - port: 5000
          name: http
        selector:
          app: helloworld
      ---
      apiVersion: apps/v1
      kind: Deployment
      metadata:
        name: helloworld-v1
        labels:
          app: helloworld
          version: v1
      spec:
        replicas: 1
        selector:
          matchLabels:
            app: helloworld
            version: v1
        template:
          metadata:
            labels:
              app: helloworld
              version: v1
          spec:
            containers:
            - name: helloworld
              image: docker.io/istio/examples-helloworld-v1:1.0
              resources:
                requests:
                  cpu: "100m"
              imagePullPolicy: IfNotPresent #Always
              ports:
              - containerPort: 5000
      ---
      apiVersion: apps/v1
      kind: Deployment
      metadata:
        name: helloworld-v2
        labels:
          app: helloworld
          version: v2
      spec:
        replicas: 1
        selector:
          matchLabels:
            app: helloworld
            version: v2
        template:
          metadata:
            labels:
              app: helloworld
              version: v2
          spec:
            containers:
            - name: helloworld
              image: docker.io/istio/examples-helloworld-v2:1.0
              resources:
                requests:
                  cpu: "100m"
              imagePullPolicy: IfNotPresent #Always
              ports:
              - containerPort: 5000




(3) Deploy HelloWorld V1

    Deploy the helloworld-v1 application to cluster1:
    $ kubectl apply --context="${CTX_CLUSTER1}" \
        -f samples/helloworld/helloworld.yaml \
        -l version=v1 -n sample


    Confirm the helloworld-v1 pod status:
    $ kubectl get pod --context="${CTX_CLUSTER1}" -n sample -l app=helloworld



(4) Deploy HelloWorld V2

    Deploy the helloworld-v2 application to cluster2:
    $ kubectl apply --context="${CTX_CLUSTER2}" \
        -f samples/helloworld/helloworld.yaml \
        -l version=v2 -n sample


    Confirm the status the helloworld-v2 pod status:
    $ kubectl get pod --context="${CTX_CLUSTER2}" -n sample -l app=helloworld




(5) Deploy curl

    Deploy the curl application to both clusters:
    $ kubectl apply --context="${CTX_CLUSTER1}" \
        -f samples/curl/curl.yaml -n sample
    $ kubectl apply --context="${CTX_CLUSTER2}" \
        -f samples/curl/curl.yaml -n sample


    Confirm the status curl pod on cluster1,2:
    $ kubectl get pod --context="${CTX_CLUSTER1}" -n sample -l app=curl
    $ kubectl get pod --context="${CTX_CLUSTER2}" -n sample -l app=curl


      (cf.) clu1 [212]{~/istio-1.24.3}# cat samples/curl/curl.yaml/*{{{*/
      apiVersion: v1
      kind: ServiceAccount
      metadata:
        name: curl
      ---
      apiVersion: v1
      kind: Service
      metadata:
        name: curl
        labels:
          app: curl
          service: curl
      spec:
        ports:
        - port: 80
          name: http
        selector:
          app: curl
      ---
      apiVersion: apps/v1
      kind: Deployment
      metadata:
        name: curl
      spec:
        replicas: 1
        selector:
          matchLabels:
            app: curl
        template:
          metadata:
            labels:
              app: curl
          spec:
            terminationGracePeriodSeconds: 0
            serviceAccountName: curl
            containers:
            - name: curl
              image: curlimages/curl
              command: ["/bin/sleep", "infinity"]
              imagePullPolicy: IfNotPresent
              volumeMounts:
              - mountPath: /etc/curl/tls
                name: secret-volume
            volumes:
            - name: secret-volume
              secret:
                secretName: curl-secret
                optional: true/*}}}*/



(6) Verifying Cross-Cluster Traffic
  To verify that cross-cluster load balancing works as expected, 
  call the HelloWorld service several times using the curl pod. To ensure load balancing is working properly, 
  call the HelloWorld service from all clusters in your deployment.

    Send one request from the curl pod on cluster1 to the HelloWorld service:
    $ kubectl exec --context="${CTX_CLUSTER1}" -n sample -c curl \
        "$(kubectl get pod --context="${CTX_CLUSTER1}" -n sample -l \
        app=curl -o jsonpath='{.items[0].metadata.name}')" \
        -- curl -sS helloworld.sample:5000/hello


    Repeat this request several times and verify that the HelloWorld version should toggle between v1 and v2:


      --- test logs ---

      clu1 {~/istio-1.24.3}# kubectl get pod --context="${CTX_CLUSTER1}" -n sample -l app=curl -o jsonpath='{.items[0].metadata.name}'
      curl-5b549b49b8-tjrhv

      clu1 {~/istio-1.24.3}# kubectl exec --context="${CTX_CLUSTER1}" -n sample -c curl \
          "$(kubectl get pod --context="${CTX_CLUSTER1}" -n sample -l \
          app=curl -o jsonpath='{.items[0].metadata.name}')" \
          -- curl -sS helloworld.sample:5000/hello

      Hello version: v2, instance: helloworld-v2-7dcd9b496d-95qkh


      clu1 {~/istio-1.24.3}# kubectl exec --context="${CTX_CLUSTER1}" -n sample -c curl \
          "$(kubectl get pod --context="${CTX_CLUSTER1}" -n sample -l \
          app=curl -o jsonpath='{.items[0].metadata.name}')" \
          -- curl -sS helloworld.sample:5000/hello

      Hello version: v1, instance: helloworld-v1-6d65866976-65drm


      clu1 {~/istio-1.24.3}# kubectl exec --context="${CTX_CLUSTER1}" -n sample -c curl \
          "$(kubectl get pod --context="${CTX_CLUSTER1}" -n sample -l \
          app=curl -o jsonpath='{.items[0].metadata.name}')" \
          -- curl -sS helloworld.sample:5000/hello

      Hello version: v2, instance: helloworld-v2-7dcd9b496d-95qkh



      <<K9s-Shell>> Pod: sample/curl-5b549b49b8-tjrhv | Container: curl
      ~ $ while true; do curl -sS helloworld.sample:5000/hello; sleep 1; done
      Hello version: v2, instance: helloworld-v2-7dcd9b496d-95qkh
      Hello version: v1, instance: helloworld-v1-6d65866976-65drm
      Hello version: v1, instance: helloworld-v1-6d65866976-65drm
      Hello version: v1, instance: helloworld-v1-6d65866976-65drm
      Hello version: v1, instance: helloworld-v1-6d65866976-65drm
      Hello version: v1, instance: helloworld-v1-6d65866976-65drm
      Hello version: v1, instance: helloworld-v1-6d65866976-65drm
      Hello version: v1, instance: helloworld-v1-6d65866976-65drm
      Hello version: v2, instance: helloworld-v2-7dcd9b496d-95qkh
      Hello version: v1, instance: helloworld-v1-6d65866976-65drm
      Hello version: v2, instance: helloworld-v2-7dcd9b496d-95qkh
      Hello version: v1, instance: helloworld-v1-6d65866976-65drm
      ^C
      ~ $ exit




 -- Now repeat this process from the curl pod on cluster2:
      $ kubectl exec --context="${CTX_CLUSTER2}" -n sample -c curl \
          "$(kubectl get pod --context="${CTX_CLUSTER2}" -n sample -l \
          app=curl -o jsonpath='{.items[0].metadata.name}')" \
          -- curl -sS helloworld.sample:5000/hello



      <<K9s-Shell>> Pod: sample/curl-5b549b49b8-tn55n | Container: curl
      ~ $ while true; do curl -sS helloworld.sample:5000/hello; sleep 1; done
      Hello version: v1, instance: helloworld-v1-6d65866976-65drm
      Hello version: v2, instance: helloworld-v2-7dcd9b496d-95qkh
      Hello version: v1, instance: helloworld-v1-6d65866976-65drm
      Hello version: v2, instance: helloworld-v2-7dcd9b496d-95qkh
      ^C
      ~ $ exit






























