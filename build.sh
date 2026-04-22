#!/usr/bin/env bash
set -euo pipefail

CHART="helm/posthog/Chart.yaml"
VERSION=$(grep '^version:' "$CHART" | awk '{print $2}')
POSTHOG_COMMIT=$(cat images/clickhouse/POSTHOG_COMMIT | tr -d '[:space:]')
REGISTRY="${REGISTRY:-ghcr.io/watts-ai}"
IMAGE="${REGISTRY}/posthog-clickhouse"
TAG="${VERSION}"

echo "Building ${IMAGE}:${TAG}"
echo "  Chart version:   ${VERSION}"
echo "  PostHog commit:  ${POSTHOG_COMMIT}"

docker build \
    --build-arg POSTHOG_COMMIT="${POSTHOG_COMMIT}" \
    -t "${IMAGE}:${TAG}" \
    -t "${IMAGE}:latest" \
    -f images/clickhouse/Dockerfile \
    .

echo ""
echo "Built: ${IMAGE}:${TAG}"
echo "To push: docker push ${IMAGE}:${TAG} && docker push ${IMAGE}:latest"
