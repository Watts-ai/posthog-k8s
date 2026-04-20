# Contributing

## Updating PostHog version

1. Find the desired commit SHA on [PostHog's master branch](https://github.com/PostHog/posthog/commits/master)
2. Update `appVersion` in `helm/posthog/Chart.yaml` to the new SHA
3. Bump `version` in `helm/posthog/Chart.yaml` (semver)
4. Run `./build.sh` to build the ClickHouse image locally
5. Push to main — CI builds + publishes both the ClickHouse image and the Helm chart

## Building locally

```bash
# Build the custom ClickHouse image (reads appVersion from Chart.yaml)
./build.sh

# Lint the chart
helm lint ./helm/posthog

# Render templates (no cluster needed)
helm template posthog ./helm/posthog

# Install to a cluster
helm install posthog ./helm/posthog --set domain=posthog.example.com
```

## Release process

Pushing to `main` triggers the GitHub Actions workflow which:
1. Builds and pushes the ClickHouse image to `ghcr.io/watts-ai/posthog-clickhouse:<version>-<appVersion>`
2. Packages and pushes the Helm chart to `oci://ghcr.io/watts-ai/posthog`

Users install with:
```bash
helm install posthog oci://ghcr.io/watts-ai/posthog --version 0.1.0
```
