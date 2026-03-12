#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"${ROOT_DIR}/scripts/import_local_k1x_scripts.sh"
source "${ROOT_DIR}/scripts/reference/build_scripts/01-env.sh"
"${ROOT_DIR}/scripts/reference/build_scripts/04-overlay-update.sh"

