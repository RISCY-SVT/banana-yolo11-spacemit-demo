#!/usr/bin/env bash
set -euo pipefail

declare -A l2_groups

for cpu in /sys/devices/system/cpu/cpu[0-9]*; do
  c="$(basename "$cpu")"
  echo "== ${c} =="
  for idx in "$cpu"/cache/index*; do
    level="$(cat "$idx/level")"
    type="$(cat "$idx/type")"
    size="$(cat "$idx/size")"
    shared="$(cat "$idx/shared_cpu_list")"
    echo "$(basename "$idx") level=${level} type=${type} size=${size} shared_cpu_list=${shared}"
    if [[ "$level" == "2" && "$type" == "Unified" ]]; then
      l2_groups["$shared"]=1
    fi
  done
done

echo
echo "== L2 shared_cpu_list groups =="
for g in "${!l2_groups[@]}"; do
  echo "$g"
done
