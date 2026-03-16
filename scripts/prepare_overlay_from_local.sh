#!/usr/bin/env bash
## @file prepare_overlay_from_local.sh
## @brief Refresh the canonical K1X sysroot overlay using imported local helpers.
## @details This wrapper makes the overlay flow discoverable from the demo repo
## while still reusing the already-validated local K1X scripts.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"${ROOT_DIR}/scripts/import_local_k1x_scripts.sh"
source "${ROOT_DIR}/scripts/reference/build_scripts/01-env.sh"
"${ROOT_DIR}/scripts/reference/build_scripts/04-overlay-update.sh"
