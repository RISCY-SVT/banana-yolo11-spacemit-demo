#!/usr/bin/env bash
set -euo pipefail

echo "== uname -a =="
uname -a
echo

echo "== lscpu =="
lscpu
echo

echo "== /proc/cpuinfo (head) =="
head -n 40 /proc/cpuinfo
echo

echo "== memory (free -h) =="
free -h
echo

echo "== cpufreq =="
for cpu in /sys/devices/system/cpu/cpu[0-9]*; do
  c="$(basename "$cpu")"
  if [[ -d "$cpu/cpufreq" ]]; then
    echo "[$c]"
    echo "governor=$(cat "$cpu/cpufreq/scaling_governor" 2>/dev/null || echo n/a)"
    echo "max_freq=$(cat "$cpu/cpufreq/scaling_max_freq" 2>/dev/null || echo n/a)"
    echo "cur_freq=$(cat "$cpu/cpufreq/scaling_cur_freq" 2>/dev/null || echo n/a)"
  else
    echo "[$c] no cpufreq"
  fi
done
echo

echo "== thermal zones =="
for tz in /sys/class/thermal/thermal_zone*; do
  if [[ -e "$tz" ]]; then
    t="$(basename "$tz")"
    type="$(cat "$tz/type" 2>/dev/null || echo unknown)"
    temp="$(cat "$tz/temp" 2>/dev/null || echo n/a)"
    echo "${t} ${type} ${temp}"
  fi
done
echo

echo "== OpenMP env =="
printenv | grep -E '^(OMP|GOMP)_' || true
