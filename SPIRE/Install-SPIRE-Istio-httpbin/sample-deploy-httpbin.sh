#!/bin/bash
set -x

kubectl --context=cluster1 create ns sample --dry-run=client -o yaml | kubectl apply -f -
kubectl --context=cluster1 label ns sample istio-injection=enabled --overwrite

kubectl --context=cluster1 apply -n sample -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: httpbin
spec:
  replicas: 1
  selector:
    matchLabels:
      app: httpbin
  template:
    metadata:
      labels:
        app: httpbin
    spec:
      containers:
      - name: httpbin
        image: mccutchen/go-httpbin:v2.10.0
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: httpbin
spec:
  selector:
    app: httpbin
  ports:
  - port: 80
    targetPort: 8080
    name: http
EOF

