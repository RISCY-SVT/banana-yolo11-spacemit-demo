#!/usr/bin/env bash
## @file gen_doxygen.sh
## @brief Generate local Doxygen documentation, downloading a user-local tool if needed.
## @details The helper keeps the repository self-service on developer machines
## that do not have `doxygen` installed system-wide.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE_DIR="${ROOT_DIR}/.cache/doxygen-ubuntu"
DEB_DIR="${CACHE_DIR}/debs"
TOOL_ROOT="${CACHE_DIR}/root"
OUT_DIR="${1:-${ROOT_DIR}/build/doxygen}"
LOG_FILE="${2:-${OUT_DIR}/doxygen.log}"
WARN_FILE="${OUT_DIR}/warnings.log"
TMP_DXY="${OUT_DIR}/Doxyfile.generated"

ensure_doxygen_bin() {
  if command -v doxygen >/dev/null 2>&1; then
    DOXYGEN_BIN="$(command -v doxygen)"
    return 0
  fi

  local bin="${TOOL_ROOT}/usr/bin/doxygen"
  if [[ ! -x "${bin}" ]]; then
    mkdir -p "${DEB_DIR}" "${TOOL_ROOT}"
    (
      cd "${DEB_DIR}"
      apt download doxygen libclang-cpp18 libclang1-18 libllvm18 libfmt9 libxapian30 >/dev/null
    )
    local deb
    for deb in "${DEB_DIR}"/*.deb; do
      dpkg-deb -x "${deb}" "${TOOL_ROOT}"
    done
  fi

  export LD_LIBRARY_PATH="${TOOL_ROOT}/usr/lib/x86_64-linux-gnu:${TOOL_ROOT}/usr/lib/llvm-18/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
  DOXYGEN_BIN="${bin}"
}

mkdir -p "${OUT_DIR}"
DOXYGEN_BIN=""
ensure_doxygen_bin

cp "${ROOT_DIR}/Doxyfile" "${TMP_DXY}"
{
  printf '\nOUTPUT_DIRECTORY = %s\n' "${OUT_DIR}"
  printf 'WARN_LOGFILE = %s\n' "${WARN_FILE}"
} >> "${TMP_DXY}"

{
  echo "repo_root=${ROOT_DIR}"
  echo "doxygen_bin=${DOXYGEN_BIN}"
  "${DOXYGEN_BIN}" -v
  "${DOXYGEN_BIN}" "${TMP_DXY}"
} 2>&1 | tee "${LOG_FILE}"

echo "HTML docs: ${OUT_DIR}/html/index.html"
echo "Warnings: ${WARN_FILE}"
