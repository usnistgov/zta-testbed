# Kubernetes Deployment Template (dme → sme Dependency)

This repository contains a Kubernetes deployment template where the sme service depends on the availability of the dme service.
The setup uses an initContainer to provide Docker-Compose–style dependency behavior (depends_on) within Kubernetes, ensuring that sme only starts after dme becomes reachable.

This template is designed for multi-service microservice environments and works seamlessly with Istio sidecar injection, private container registries, and service-to-service communication.

#  Features
- Two microservices: dme and sme
  - dme runs a simple HTTP service on port 8080
  - sme depends on dme and should not start until dme is reachable

- Kubernetes-native dependency handling (no depends_on)
  Implemented using:
  - initContainer for startup blocking until dme is available
  - retry + backoff logic using curl inside the initContainer

- Istio-compatible
  Namespace is labeled:
```yaml
istio-injection: enabled
```
- Optional ConfigMap support
  - Mount or consume configuration as needed.

- Supports private registries
  - imagePullSecrets included in the template.



# Fill-In Checklist (What You MUST Edit)

Before applying the template, update the following values marked "# << EDIT >>" in template files.

## 1. Namespace

Must be lowercase (RFC 1123):
```yaml
metadata.name: nist-oran
```

## 2. ServiceAccount Names

Update as needed:
```yaml
dme-sa
sme-sa
```

## 3. Container Images

Replace with your actual images:

### dme:
```yaml
image: <your-dme-image>
```

### sme:
```yaml
image: 10.5.0.2:8443/flask-hello:latest
```

## 4. Private Registry Secret (optional)

If you use a private registry, ensure the secret exists:
```yaml
imagePullSecrets:
  - name: registry-ca
```

## 5. Ports

Adjust container ports & service ports as required.

### dme:
```yaml
containerPort: 8080
service port: 8080
```

### sme:
```yaml
containerPort: 323
service port: 8323
```

## 6. ConfigMap (optional)

If your application needs config files, edit:

```yaml
data:
  app.conf: |
    key=value
    timeout=5
```

Otherwise, remove the ConfigMap and related volume/volumeMount.


## 7. Application Start Commands

Replace placeholder:
```yaml
command: ["sh", "-c", "sleep 3650d"]
```




# Service Dependency Logic (How SME waits for DME)

Kubernetes does not support native depends_on like Docker Compose.

To mimic dependency behavior:

- can be used an initContainer in sme:
  - Blocks startup until dme is reachable
  - Performs repeated curl attempts
  - Uses exponential backoff
  - Ensures sme only starts when the backend is ready

## Example snippet:
```yaml
initContainers:
- name: wait-for-dme
  image: curlimages/curl:8.10.1
  command:
  - sh
  - -c
  - |
    DME_URL="http://dme.nist-oran.svc.cluster.local:8080"
    MAX_RETRIES=30
    SLEEP=2
    i=1

    while [ $i -le $MAX_RETRIES ]; do
      if curl -sf "$DME_URL" >/dev/null; then
        exit 0
      fi
      sleep $SLEEP
      SLEEP=$((SLEEP * 2 > 30 ? 30 : SLEEP * 2))
      i=$((i+1))
    done

    exit 1
```

- What this means:
  - If dme is down → sme stays in Init state
  - No CrashLoopBackOff
  - When dme comes up → sme starts automatically

This is the most reliable Kubernetes-native pattern for service dependencies.


# How to Deploy

Apply the modified manifests you want to deploy:

```bash
kubectl apply -f template-dependency-example-dme-sme.yaml
and/or
kubectl apply -f template-general-deployment.yaml 
```

# How to uninstall
```bash
kubectl delete -f template-dependency-example-dme-sme.yaml
and/or
kubectl delete -f template-general-deployment.yaml 
```

