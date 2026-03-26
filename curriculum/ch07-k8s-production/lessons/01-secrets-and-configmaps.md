# Lesson 1: Secrets and ConfigMaps

> **Sarah:** "This is the part where I have to tell you something uncomfortable. Those database credentials in the pod logs? That was a ConfigMap being used for things ConfigMaps were never meant to hold. Let me show you the right tool for each job."

---

## The Problem with Hardcoded Configuration

Look at this Deployment:

```yaml
env:
  - name: DB_HOST
    value: "postgres.internal"
  - name: DB_PASSWORD
    value: "hunter2"
  - name: LOG_LEVEL
    value: "debug"
```

Three problems here:

1. `DB_HOST` and `LOG_LEVEL` change between environments (staging vs. production). Hardcoding them means different YAML files per environment — or worse, templating them manually.
2. `DB_PASSWORD` is a secret. It's in your Deployment YAML. That YAML is almost certainly committed to git. That git repo is probably accessible to more people than should know the database password.
3. None of this can change without redeploying the pod.

Kubernetes has two objects designed to solve this: **ConfigMap** for configuration, **Secret** for sensitive data.

---

## ConfigMap

A ConfigMap holds non-sensitive configuration as key-value pairs. Think of it as a dictionary that pods can read from — either as environment variables or as files.

### When to use a ConfigMap

- Feature flags: `FEATURE_NEW_CHECKOUT=true`
- Log levels: `LOG_LEVEL=info`
- Service URLs: `API_BASE_URL=https://api.internal`
- Application settings that vary by environment
- Config files (`nginx.conf`, `app.properties`) that pods need to read

### When NOT to use a ConfigMap

- Passwords
- API keys
- Tokens
- Private keys
- Anything you would not write on a whiteboard in the office

If the value would be embarrassing in a public log, it belongs in a Secret.

### Creating a ConfigMap

**From literal values:**

```bash
kubectl create configmap app-config \
  --from-literal=LOG_LEVEL=info \
  --from-literal=API_BASE_URL=https://api.internal \
  -n learn-ch07
```

**From a file:**

```bash
# nginx.conf exists as a file on your machine
kubectl create configmap nginx-config \
  --from-file=nginx.conf \
  -n learn-ch07
```

The filename becomes the key. The file contents become the value.

**From YAML (declarative — the right way for anything you want in version control):**

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: learn-ch07
data:
  LOG_LEVEL: "info"
  API_BASE_URL: "https://api.internal"
  FEATURE_NEW_CHECKOUT: "true"
```

Apply it: `kubectl apply -f app-config.yaml`

### Reading a ConfigMap in a Pod

**As environment variables (individual keys):**

```yaml
env:
  - name: LOG_LEVEL
    valueFrom:
      configMapKeyRef:
        name: app-config
        key: LOG_LEVEL
```

**As environment variables (all keys at once):**

```yaml
envFrom:
  - configMapRef:
      name: app-config
```

Every key in the ConfigMap becomes an environment variable in the pod. Convenient, but it means every value in the ConfigMap lands in the process environment — which is visible in `kubectl exec` and process listings. Fine for non-sensitive config.

**As a mounted volume (for config files):**

```yaml
volumes:
  - name: nginx-config-vol
    configMap:
      name: nginx-config

containers:
  - name: nginx
    volumeMounts:
      - name: nginx-config-vol
        mountPath: /etc/nginx/conf.d
```

Each key in the ConfigMap becomes a file in the mounted directory. This is how you inject an entire `nginx.conf` or `application.properties` into a container without baking it into the image.

---

## Secret

A Secret is structurally similar to a ConfigMap, but it is designed for sensitive data. It has a few important properties ConfigMaps do not.

### What Secrets actually do differently

- Values are base64-encoded (important caveat below)
- Secrets are not included in `kubectl get all` output
- They can be configured to only be delivered to nodes that need them
- RBAC policies commonly restrict `get secret` to fewer principals than `get configmap`
- Some storage backends (etcd encryption, external secret operators) integrate specifically with Secrets

### The most important thing to understand about Secrets

**base64 is not encryption.**

```bash
echo -n "hunter2" | base64
# aHVudGVyMg==

echo -n "aHVudGVyMg==" | base64 --decode
# hunter2
```

Anyone who can read the Secret object can decode the value in two seconds. Base64 exists here for one reason: it lets binary data (like TLS certificates and private keys) be stored in YAML, which is a text format. It is encoding, not encryption.

By default, Kubernetes stores Secrets in etcd as base64. If someone has access to your etcd data, they have your secrets in plaintext. This is why in production you:

1. Enable etcd encryption at rest
2. Use an external secret manager (more on this below)
3. Restrict who can `kubectl get secret` with RBAC

For learning and development, base64-encoded Secrets are fine. Understand what they are.

### Creating a Secret

**From literal values:**

```bash
kubectl create secret generic db-credentials \
  --from-literal=DB_PASSWORD=hunter2 \
  --from-literal=DB_USER=cloudbrew \
  -n learn-ch07
```

**From a file (useful for TLS certs, `.env` files):**

```bash
kubectl create secret generic api-keys \
  --from-file=api_key.txt \
  -n learn-ch07
```

**From YAML (declarative):**

You must base64-encode the values yourself when writing YAML:

```bash
echo -n "hunter2" | base64
# aHVudGVyMg==
```

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
  namespace: learn-ch07
type: Opaque
data:
  DB_PASSWORD: aHVudGVyMg==
  DB_USER: Y2xvdWRicmV3
```

Or use `stringData` to let Kubernetes do the encoding:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
  namespace: learn-ch07
type: Opaque
stringData:
  DB_PASSWORD: "hunter2"
  DB_USER: "cloudbrew"
```

`stringData` is write-only — K8s converts it to base64-encoded `data` when storing. When you `kubectl get secret -o yaml`, you always see the base64 form.

### Using a Secret in a Pod

**As environment variables:**

```yaml
env:
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: db-credentials
        key: DB_PASSWORD
```

**As a mounted volume:**

```yaml
volumes:
  - name: db-creds-vol
    secret:
      secretName: db-credentials

containers:
  - name: api
    volumeMounts:
      - name: db-creds-vol
        mountPath: /etc/secrets
        readOnly: true
```

Each key in the Secret becomes a file at `/etc/secrets/<key>`. The application reads the file contents at runtime. This has one advantage over environment variables: if the Secret is updated and the pod is restarted, the new values are picked up. Environment variables are baked in at pod start.

### Inspecting Secrets

```bash
# See secret metadata (not values)
kubectl get secret db-credentials -n learn-ch07

# See base64-encoded values
kubectl get secret db-credentials -n learn-ch07 -o yaml

# Decode a specific value
kubectl get secret db-credentials -n learn-ch07 \
  -o jsonpath='{.data.DB_PASSWORD}' | base64 --decode
```

---

## ConfigMap vs Secret — Decision Table

| Situation | Use |
|-----------|-----|
| Log level setting | ConfigMap |
| Feature flag | ConfigMap |
| Service URL | ConfigMap |
| nginx.conf | ConfigMap |
| Database password | Secret |
| API key | Secret |
| OAuth client secret | Secret |
| TLS certificate | Secret (type `kubernetes.io/tls`) |
| Docker registry credentials | Secret (type `kubernetes.io/dockerconfigjson`) |

If you are unsure, ask: "Would I be comfortable with this value appearing in a public log?" If no, it is a Secret.

---

## Production Best Practices

**Never commit secrets to git.**

The moment a secret touches a git commit, it is compromised — permanently, even if you delete the commit. Git history is forever. Use `.gitignore` for any file containing secret YAML. Better yet, never write secret values to a file at all; create them with `kubectl create secret generic --from-literal` or use an automated pipeline.

**Use an external secret manager.**

For real production workloads, Kubernetes Secrets are a transit format, not a storage format. The source of truth lives in:

- **HashiCorp Vault** — The most common open-source option. Secrets are stored encrypted, accessed via policies, and rotated automatically.
- **AWS Secrets Manager / Parameter Store** — Native to AWS-hosted clusters. IAM policies control access.
- **GCP Secret Manager** / **Azure Key Vault** — Same pattern on other clouds.

Tools like the **External Secrets Operator** watch your external secret manager and automatically sync values into Kubernetes Secrets, so pods get the right secrets without anyone touching raw YAML.

**Restrict access with RBAC.**

Separate your RBAC policies so that application pods can only read the specific Secrets they need, not all Secrets in the namespace. We will not cover RBAC in depth in this chapter, but know that `kubectl auth can-i get secrets --as=system:serviceaccount:learn-ch07:default` is how you check what a pod is actually allowed to do.

**Rotate secrets.**

When a credential is compromised — or even suspected of being compromised — rotate it immediately. A credential that was in a public log for five minutes should be treated as fully compromised.

---

## Quick Reference

```bash
# Create ConfigMap
kubectl create configmap <name> --from-literal=KEY=VALUE -n <namespace>
kubectl apply -f configmap.yaml

# Create Secret
kubectl create secret generic <name> --from-literal=KEY=VALUE -n <namespace>
kubectl apply -f secret.yaml

# Inspect
kubectl get configmap <name> -n <namespace> -o yaml
kubectl get secret <name> -n <namespace> -o yaml

# Decode a secret value
kubectl get secret <name> -n <namespace> -o jsonpath='{.data.<key>}' | base64 --decode

# List all in namespace
kubectl get configmaps -n <namespace>
kubectl get secrets -n <namespace>
```

---

> **Sarah:** "The credentials-in-logs incident happens to everyone at least once. The fix is always the same: move the value into a Secret, update the pod to read from the Secret, redeploy, and rotate the credential. The rotation part is what people skip. Don't skip it."

**Next:** [Rolling Updates](02-rolling-updates.md)
