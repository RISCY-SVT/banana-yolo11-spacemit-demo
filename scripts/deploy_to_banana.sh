#!/usr/bin/env bash
## @file deploy_to_banana.sh
## @brief Build and deploy the staged runtime, binaries, scripts, and models to Banana.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${BANANA_SSH_TARGET:-svt@banana}"
BOARD_DIR="${BOARD_DIR:-/home/svt/banana-yolo11-spacemit-demo}"

source /data/build_scripts/01-env.sh
source "${ROOT_DIR}/scripts/common.sh"

"${ROOT_DIR}/scripts/build_cross.sh"
"${ROOT_DIR}/scripts/fetch_models.sh"

VARIANTS="${BANANA_DEMO_DEPLOY_VARIANTS:-${BANANA_DEMO_BUILD_VARIANTS:-rt123,rt201}}"
IFS=',' read -r -a DEPLOY_VARIANTS <<<"${VARIANTS}"
runtime_mkdir_cmd="mkdir -p '${BOARD_DIR}' '${BOARD_DIR}/bin' '${BOARD_DIR}/app/bin' '${BOARD_DIR}/scripts' '${BOARD_DIR}/assets' '${BOARD_DIR}/logs' '${BOARD_DIR}/outputs' '${BOARD_DIR}/inputs'"
for runtime_tag in "${DEPLOY_VARIANTS[@]}"; do
  runtime_mkdir_cmd="${runtime_mkdir_cmd} '${BOARD_DIR}/runtime/${runtime_tag}'"
done
ssh "${TARGET}" "${runtime_mkdir_cmd}"
for runtime_tag in "${DEPLOY_VARIANTS[@]}"; do
  rsync -avc "${ROOT_DIR}/install/k1x-release-${runtime_tag}/bin/banana_yolo11_demo" "${TARGET}:${BOARD_DIR}/bin/banana_yolo11_demo_${runtime_tag}"
  if [[ -x "${ROOT_DIR}/install/k1x-release-${runtime_tag}/bin/banana_yolo11_coco_eval" ]]; then
    rsync -avc "${ROOT_DIR}/install/k1x-release-${runtime_tag}/bin/banana_yolo11_coco_eval" "${TARGET}:${BOARD_DIR}/bin/banana_yolo11_coco_eval_${runtime_tag}"
  fi
  rsync -av "$(banana_demo_runtime_vendor_root "${ROOT_DIR}" "${runtime_tag}")/" "${TARGET}:${BOARD_DIR}/runtime/${runtime_tag}/"
done
# Keep a compatibility binary at the historical app/bin path used by older
# loader checks. Product scripts still select the top-level runtime-specific
# binaries in bin/.
if [[ -x "${ROOT_DIR}/install/k1x-release-rt201/bin/banana_yolo11_demo" ]]; then
  rsync -avc "${ROOT_DIR}/install/k1x-release-rt201/bin/banana_yolo11_demo" "${TARGET}:${BOARD_DIR}/app/bin/banana_yolo11_demo"
fi
rsync -av "${ROOT_DIR}/models/" "${TARGET}:${BOARD_DIR}/models/"
rsync -av "${ROOT_DIR}/assets/" "${TARGET}:${BOARD_DIR}/assets/"
rsync -av "${ROOT_DIR}/scripts/" "${TARGET}:${BOARD_DIR}/scripts/"
rsync -av "${ROOT_DIR}/docs/" "${TARGET}:${BOARD_DIR}/docs/"
rsync -av "${ROOT_DIR}/third_party_manifest/" "${TARGET}:${BOARD_DIR}/third_party_manifest/"
rsync -av "${ROOT_DIR}/README.md" "${TARGET}:${BOARD_DIR}/"

ssh "${TARGET}" "mkdir -p '${BOARD_DIR}/opencv'"
rsync -av /data/opencv/install-k1x-gtk3/lib/ "${TARGET}:${BOARD_DIR}/opencv/lib/"
echo "Deployed to ${TARGET}:${BOARD_DIR}"
