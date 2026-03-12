#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCK_FILE="${ROOT_DIR}/third_party_manifest/runtime.lock"
OUT_DIR="${ROOT_DIR}/third_party/vendor"
CACHE_DIR="${ROOT_DIR}/.deps/cache"

mkdir -p "${OUT_DIR}" "${CACHE_DIR}"

URL="$(awk -F= '$1=="url"{print $2}' "${LOCK_FILE}")"
SHA256_EXPECTED="$(awk -F= '$1=="sha256"{print $2}' "${LOCK_FILE}")"
NAME="$(awk -F= '$1=="name"{print $2}' "${LOCK_FILE}")"
ARCHIVE="${CACHE_DIR}/${NAME}.tar.gz"
EXTRACT_DIR="${OUT_DIR}/${NAME}"

if [[ -d "${EXTRACT_DIR}" && -f "${EXTRACT_DIR}/include/spacemit_ort_env.h" ]]; then
  echo "Vendor runtime already prepared: ${EXTRACT_DIR}"
  exit 0
fi

if [[ ! -f "${ARCHIVE}" ]]; then
  if [[ -f "/data/SpacemiT/${NAME}.tar.gz" ]]; then
    cp -f "/data/SpacemiT/${NAME}.tar.gz" "${ARCHIVE}"
  else
    curl -L --fail --output "${ARCHIVE}" "${URL}"
  fi
fi

echo "${SHA256_EXPECTED}  ${ARCHIVE}" | sha256sum -c

rm -rf "${EXTRACT_DIR}"
tar -xf "${ARCHIVE}" -C "${OUT_DIR}"
test -f "${EXTRACT_DIR}/include/spacemit_ort_env.h"
echo "Prepared vendor runtime at ${EXTRACT_DIR}"

