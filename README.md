# posthog-k8s

Unofficial Helm chart and custom images for self-hosting PostHog on Kubernetes, based on the upstream hobby deployment.

## Quick start

```bash
helm install posthog oci://ghcr.io/watts-ai/posthog \
  --set domain=posthog.example.com
```

PostHog will be available once all pods are ready (~5-10 minutes on first install due to database migrations). The first user to sign up becomes the admin.

**Note:** The chart exposes PostHog over plain HTTP on port 8000. The `domain` value is used by PostHog internally (site URL, CORS, cookie domain) but does **not** configure TLS, DNS, or ingress routing. You are responsible for terminating TLS and routing traffic to the service (e.g., via an Ingress resource, a load balancer, or a reverse proxy).

## Configuration

See all available values:

```bash
helm show values oci://ghcr.io/watts-ai/posthog
```

### Values pattern

All values that map to environment variables accept two forms:

**Literal string** — rendered as a `value:` field:
```yaml
email:
  host: "smtp.example.com"
  port: "587"
```

**Map** — rendered as-is into the Kubernetes env spec (typically `valueFrom:`):
```yaml
email:
  host:
    valueFrom:
      secretKeyRef:
        name: my-smtp-secret
        key: host
  password:
    valueFrom:
      secretKeyRef:
        name: my-smtp-secret
        key: password
```

Bare integers and booleans are **not allowed** — wrap them in quotes (`port: "587"`, `useTLS: "true"`). The chart will fail with a clear error if you forget.

### Validation

Sections activate when their trigger fields are set. If you provide a partial configuration, the chart fails at template time with a descriptive error — before anything is applied to the cluster.

| Section | Trigger fields (all required together) | Optional fields |
|---------|----------------------------------------|-----------------|
| Email | `host`, `user` | `password`, `defaultFrom` |
| Slack | `clientId`, `clientSecret`, `signingSecret` | — |
| SSO GitHub | `key`, `secret` | — |
| SSO GitLab | `key`, `secret` | — |
| SSO Google | `key`, `secret` | — |
| SSO OIDC | `key`, `secret`, `endpoint` | `iconUrl`, `displayName` |
| Cloudflare Turnstile | `siteKey`, `secretKey` | — |
| WorkOS Radar | `apiKey` | — |
| StatsD | `host` | `prefix` |
| Object Storage creds | `accessKeyId`, `secretAccessKey` | — |

### Common overrides

```yaml
# values.yaml
domain: posthog.example.com

# Disable TLS cookie requirement (e.g. local testing without HTTPS)
siteUrl: "http://posthog.example.com:8000"
secureCookies: "false"

# Allow multiple organizations
multiOrgEnabled: "true"

# SSO with Google (literal values)
sso:
  google:
    key: "your-google-client-id"
    secret: "your-google-client-secret"

# SSO with Google (from Kubernetes Secret)
sso:
  google:
    key:
      valueFrom:
        secretKeyRef:
          name: google-oauth
          key: client-id
    secret:
      valueFrom:
        secretKeyRef:
          name: google-oauth
          key: client-secret

# Email via AWS SES
email:
  host: "email-smtp.us-east-1.amazonaws.com"
  port: "587"
  user:
    valueFrom:
      secretKeyRef:
        name: ses-credentials
        key: smtp-user
  password:
    valueFrom:
      secretKeyRef:
        name: ses-credentials
        key: smtp-password
  useTLS: "true"
  defaultFrom: "noreply@example.com"

# Ingress
ingress:
  enabled: true
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
  tls:
    - secretName: posthog-tls
      hosts:
        - posthog.example.com

# Disable GeoIP (required for airgapped deployments)
geoip:
  enabled: false

# External S3 instead of built-in SeaweedFS
objectStorage:
  type: external
  external:
    endpoint: "https://s3.amazonaws.com"
    region: "us-east-1"
    bucket: "my-posthog-bucket"

# Storage sizes
persistence:
  clickhouse:
    size: 50Gi
  postgres:
    size: 20Gi
```

Install with overrides:

```bash
helm install posthog oci://ghcr.io/watts-ai/posthog \
  --version <version> \
  -f values.yaml
```

### Secrets

The chart auto-generates cryptographically secure secrets on first install and persists them across upgrades. Each infrastructure secret has a corresponding values.yaml field that overrides the auto-generated value when set:

```yaml
# Override individual secrets — these take precedence over the chart-generated Secret.
# Works regardless of secrets.create setting.
postgres:
  password: "my-literal-password"    # literal string
clickhouse:
  apiPassword:
    valueFrom:                        # or a secretKeyRef map
      secretKeyRef:
        name: my-clickhouse-secret
        key: api-password
secretKey:
  valueFrom:
    secretKeyRef:
      name: my-app-secret
      key: posthog-secret
```

**How it works:** For each secret (e.g., `postgres.password`), the chart checks if you provided a value. If yes, your value is used directly. If empty (the default), the chart falls back to its own auto-generated Secret. This means you can override some secrets while letting the chart manage the rest — they're independent.

**`secrets.create`** controls whether the chart generates a Secret resource as a fallback target. When `true` (the default), the chart creates a Secret with auto-generated passwords for any fields you didn't override. The auto-generated values are harmless even if unused. Set to `false` only if you're managing **all** secrets externally and want to avoid the extra resource:

```yaml
secrets:
  create: false
  name: my-posthog-secrets  # must contain keys: posthog-secret, encryption-salt-keys,
                             # postgres-password, clickhouse-api-password,
                             # clickhouse-app-password, s3-access-key-id, s3-secret-access-key
```

### Images

All PostHog image tags default to the chart's `appVersion` (a PostHog commit SHA). Infrastructure images are pinned to specific versions. Override any image for airgapped/mirrored registries:

```yaml
images:
  posthog:
    repository: my-registry.internal/posthog/posthog
  clickhouse:
    repository: my-registry.internal/posthog-clickhouse
  capture:
    repository: my-registry.internal/posthog/capture
```

## Architecture

The chart deploys ~30 services mirroring the upstream PostHog hobby deployment:

| Category | Services |
|----------|----------|
| **Infrastructure** | PostgreSQL, Redis, ClickHouse, ZooKeeper, Redpanda (Kafka), SeaweedFS (S3), Elasticsearch |
| **PostHog Python** | web (Django + migrations), worker (Celery) |
| **PostHog Node.js** | plugins, ingestion-general, ingestion-sessionreplay, ingestion-error-tracking, ingestion-logs, ingestion-traces, recording-api |
| **PostHog Rust/Go** | capture, replay-capture, feature-flags, property-defs-rs, cyclotron-janitor, cymbal, livestream |
| **Temporal** | temporal, temporal-admin-tools, temporal-ui, temporal-django-worker |
| **Jobs** | kafka-init, geoip-init (optional) |

ClickHouse uses a custom image (`ghcr.io/watts-ai/posthog-clickhouse`) with PostHog's XML configs, UDF binaries, and IDL schemas baked in.

## Upgrading

```bash
helm upgrade posthog oci://ghcr.io/watts-ai/posthog --version <version>
```

The web pod runs database migrations automatically before starting the server. Rolling updates ensure zero downtime.

## Instance settings

Email (SMTP), Slack integration, SSO providers, and other instance-level settings can be configured either via `values.yaml` (recommended for GitOps) or at runtime in the PostHog UI at `/instance/settings` (requires staff user). Chart-level configuration takes precedence.

## Docker Compose (local testing)

A `docker-compose.yml` is included for local testing outside of Kubernetes:

```bash
cp .env.example .env  # edit domain and secrets
docker compose build  # builds custom ClickHouse image
docker compose up -d  # starts all services
# Visit http://localhost:8000
```

## Environment variables

All [PostHog environment variables](https://posthog.com/docs/self-host/configure/environment-variables) are supported as first-class values in `values.yaml`. See the values file for the full list.
