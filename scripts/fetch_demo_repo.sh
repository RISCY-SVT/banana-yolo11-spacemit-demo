#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${ROOT_DIR}/third_party"
REPO_URL="$(awk -F= '$1=="vendor_demo_repo"{print $2}' "${ROOT_DIR}/third_party_manifest/models.lock")"
DEST="${OUT_DIR}/spacemit-demo"

mkdir -p "${OUT_DIR}"

if [[ -d "${DEST}/.git" ]]; then
  git -C "${DEST}" fetch --all --tags
  git -C "${DEST}" pull --ff-only
else
  git clone "${REPO_URL}" "${DEST}"
fi

git -C "${DEST}" rev-parse HEAD

