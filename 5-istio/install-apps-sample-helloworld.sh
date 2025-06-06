#!/bin/bash

. ../env-istio.sh

#load helloworld and sleep images

echo "Pulling images to a docker host..."
docker pull docker.io/istio/examples-helloworld-v1:1.0
docker pull docker.io/istio/examples-helloworld-v2:1.0
docker pull docker.io/kong/httpbin
docker pull curlimages/curl


# To begin, create the sample namespace in each cluster:
kubectl create --context="${CTX_CLUSTER1}" namespace sample
kubectl create --context="${CTX_CLUSTER2}" namespace sample


#Enable automatic sidecar injection for the sample namespace:
kubectl label --context="${CTX_CLUSTER1}" namespace sample istio-injection=enabled
kubectl label --context="${CTX_CLUSTER2}" namespace sample istio-injection=enabled


cat <<EOF > helloworld.yaml
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
EOF



# Create the HelloWorld service in both clusters:
kubectl apply --context="${CTX_CLUSTER1}" -f helloworld.yaml -l service=helloworld -n sample
kubectl apply --context="${CTX_CLUSTER2}" -f helloworld.yaml -l service=helloworld -n sample




# Deploy HelloWorld V1
# Deploy the helloworld-v1 application to cluster1:
kubectl apply --context="${CTX_CLUSTER1}" -f helloworld.yaml -l version=v1 -n sample

# Deploy HelloWorld V2
# Deploy the helloworld-v2 application to cluster2:
kubectl apply --context="${CTX_CLUSTER2}" -f helloworld.yaml -l version=v2 -n sample



cat <<EOF > curl.yaml
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
          optional: true
EOF



# Deploy curl
# Deploy the curl application to both clusters:
kubectl apply --context="${CTX_CLUSTER1}" -f curl.yaml -n sample
kubectl apply --context="${CTX_CLUSTER2}" -f curl.yaml -n sample


