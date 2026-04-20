#!/usr/bin/env bash
set -euo pipefail

CHART="helm/posthog/Chart.yaml"
VERSION=$(grep '^version:' "$CHART" | awk '{print $2}')
APP_VERSION=$(grep '^appVersion:' "$CHART" | awk '{print $2}' | tr -d '"')
REGISTRY="${REGISTRY:-ghcr.io/watts-ai}"
IMAGE="${REGISTRY}/posthog-clickhouse"
TAG="${VERSION}-${APP_VERSION}"

echo "Building ${IMAGE}:${TAG}"
echo "  Chart version:   ${VERSION}"
echo "  PostHog commit:  ${APP_VERSION}"

docker build \
    --build-arg POSTHOG_COMMIT="${APP_VERSION}" \
    -t "${IMAGE}:${TAG}" \
    -t "${IMAGE}:latest" \
    -f images/clickhouse/Dockerfile \
    .

echo ""
echo "Built: ${IMAGE}:${TAG}"
echo "To push: docker push ${IMAGE}:${TAG} && docker push ${IMAGE}:latest"
