# Updating PostHog image versions

The chart pins PostHog app images to specific commit SHAs.

## Finding the latest commit with a published image

Not every commit has a Docker image. Check recent commits on the target
repo's master branch and verify the image exists before updating:

- **Upstream**: `posthog/posthog:<full_sha>` on Docker Hub
- **Watts fork**: `ghcr.io/watts-ai/posthog/posthog:watts-<full_sha>` on GHCR

## What to update

| File | Field | When |
|------|-------|------|
| `helm/posthog/templates/_helpers.tpl` | `posthog.upstreamCommit` | Upstream changes |
| `helm/posthog/templates/_helpers.tpl` | `posthog.wattsCommit` | Watts fork changes |
| `images/clickhouse/POSTHOG_COMMIT` | Entire file (single line) | Watts fork changes |

When updating the watts fork, both `_helpers.tpl` and `POSTHOG_COMMIT` must
be updated together.

## After updating

Bump the patch version in `helm/posthog/Chart.yaml`, then commit and push.
The release workflow will build the ClickHouse image and publish the chart.
