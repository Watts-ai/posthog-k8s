# posthog-k8s

Unofficial Helm chart and custom images for self-hosting PostHog on Kubernetes, based on the upstream hobby deployment.

## Quick start

```bash
helm install posthog oci://ghcr.io/watts-ai/posthog \
  --version 0.1.0 \
  --set domain=posthog.example.com
```

PostHog will be available at `https://posthog.example.com` once all pods are ready (~5-10 minutes on first install due to database migrations). The first user to sign up becomes the admin.

## Configuration

See all available values:

```bash
helm show values oci://ghcr.io/watts-ai/posthog --version 0.1.0
```

### Common overrides

```yaml
# values.yaml
domain: posthog.example.com

# Disable TLS cookie requirement (e.g. local testing without HTTPS)
siteUrl: "http://posthog.example.com:8000"
secureCookies: false

# Allow multiple organizations
multiOrgEnabled: true

# SSO with Google
sso:
  google:
    key: "your-google-client-id"
    secret: "your-google-client-secret"

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
  --version 0.1.0 \
  -f values.yaml
```

### Secrets

The chart auto-generates cryptographically secure secrets on first install and persists them across upgrades. To manage secrets externally (e.g. with External Secrets Operator):

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
helm upgrade posthog oci://ghcr.io/watts-ai/posthog --version 0.2.0
```

The web pod runs database migrations automatically before starting the server. Rolling updates ensure zero downtime.

## Instance settings

Email (SMTP), Slack integration, and other instance-level settings are configured in the PostHog UI at `/instance/settings` (requires staff user). These are not managed by the Helm chart.

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
