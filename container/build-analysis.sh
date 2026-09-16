#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
image_tag="${IMAGE_TAG:-ltee-oxygen-model:publication-r44}"
platform="linux/amd64"

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'EOF'
Usage: IMAGE_TAG=ltee-oxygen-model:publication-r44 container/build-analysis.sh

Builds a thin publication image from the locked linux/amd64 model-analysis
manifest and verifies its platform and provenance labels.
EOF
  exit 0
fi
if (( $# > 0 )); then
  echo "Unknown option: $1" >&2
  exit 2
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is required to build the publication analysis image." >&2
  echo "Install/start Docker Desktop, or pull the recommended image directly:" >&2
  echo "  docker pull --platform ${platform} docker.io/zafiro/o2_supply_demand_map:r44" >&2
  exit 2
fi
if ! docker info >/dev/null 2>&1; then
  echo "The Docker daemon is unavailable; start Docker Desktop first." >&2
  exit 2
fi

docker build \
  --platform "${platform}" \
  --file "${script_dir}/Dockerfile.analysis" \
  --tag "${image_tag}" \
  "${script_dir}"

observed_platform="$(docker image inspect --format '{{.Os}}/{{.Architecture}}' "${image_tag}")"
observed_version="$(docker image inspect --format '{{index .Config.Labels "org.opencontainers.image.version"}}' "${image_tag}")"
observed_base="$(docker image inspect --format '{{index .Config.Labels "org.opencontainers.image.base.digest"}}' "${image_tag}")"

[[ "${observed_platform}" == "${platform}" ]] || {
  echo "Built image platform mismatch: ${observed_platform}" >&2
  exit 2
}
[[ "${observed_version}" == "publication-r44" ]] || {
  echo "Built image analysis-version label mismatch: ${observed_version}" >&2
  exit 2
}
[[ "${observed_base}" == "sha256:32d30d8d3cae9468e466cabeaa7f51cfcc07b4a867ea66aa06c998c141067132" ]] || {
  echo "Built image base-digest label mismatch: ${observed_base}" >&2
  exit 2
}

echo "Built and labeled publication analysis image: ${image_tag}"
