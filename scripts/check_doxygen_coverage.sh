#!/usr/bin/env bash
## @file check_doxygen_coverage.sh
## @brief Verify that every tracked source/script/CMake file carries an `@file` block.
## @details The check is intentionally simple and reproducible: it scans the
## tracked repository tree instead of generated build outputs and exits non-zero
## if any covered file lacks a file-level Doxygen marker.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

## @brief Print the tracked files that should carry `@file`.
list_tracked_doc_files() {
  git ls-files | grep -E '(^CMakeLists.txt$|\.cmake$|\.sh$|\.py$|\.(h|hpp|c|cc|cpp)$)'
}

## @brief Return the subset of tracked files missing a file-level Doxygen marker.
missing_file_blocks() {
  while IFS= read -r file; do
    if ! rg -q '@file' "${file}"; then
      printf '%s\n' "${file}"
    fi
  done < <(list_tracked_doc_files)
}

echo "# Doxygen file coverage"
echo
echo "tracked_doc_files=$(list_tracked_doc_files | wc -l)"

missing="$(missing_file_blocks || true)"
if [[ -z "${missing}" ]]; then
  echo "missing_at_file=0"
  exit 0
fi

echo "missing_at_file=$(printf '%s\n' "${missing}" | sed '/^$/d' | wc -l)"
printf '%s\n' "${missing}"
exit 1
