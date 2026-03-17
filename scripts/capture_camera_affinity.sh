#!/usr/bin/env bash
## @file capture_camera_affinity.sh
## @brief Capture a reproducible camera CPU-affinity trace bundle on Banana.
## @details Runs the normal or fast-live camera profile, samples `mpstat`,
## `pidstat`, `ps -L`, and per-thread affinity masks, then stores everything in
## one output directory. Host mode deploys first and forwards execution to the
## board-local copy.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT_DIR}/scripts/common.sh"

## @brief Print CLI usage for the affinity trace helper.
usage() {
  cat <<'EOF'
Usage:
  capture_camera_affinity.sh [default|fast] [output_dir] [max_frames]

Examples:
  ./scripts/capture_camera_affinity.sh
  ./scripts/capture_camera_affinity.sh fast
  ./scripts/capture_camera_affinity.sh default ./outputs/affinity_trace 80

Purpose:
  Capture a compact board-side regression bundle for camera thread placement:
  - run log
  - mpstat -P ALL 1
  - pidstat -t -p <pid> 1
  - ps -L snapshot
  - per-thread Cpus_allowed_list snapshots

Notes:
  - default profile uses ./scripts/run_camera_demo.sh
  - fast profile uses ./scripts/run_camera_demo_fast.sh
  - board-local output defaults to ./outputs/affinity_trace_<profile>_<timestamp>
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

## @brief Run the affinity capture directly on Banana.
run_board_capture() {
  local repo_dir="$1"
  local profile="${2:-default}"
  local out_dir="$3"
  local max_frames="$4"
  local runner="run_camera_demo.sh"
  local still_name="camera_default.jpg"
  local launch_pid=""
  local launch_pid_file="${out_dir}/demo.pid"

  case "${profile}" in
    default)
      runner="run_camera_demo.sh"
      still_name="camera_default.jpg"
      [[ -n "${max_frames}" ]] || max_frames=80
      ;;
    fast|live-fast)
      runner="run_camera_demo_fast.sh"
      still_name="camera_fast.jpg"
      [[ -n "${max_frames}" ]] || max_frames=180
      ;;
    *)
      echo "ERROR: unsupported profile=${profile}; use default|fast" >&2
      return 2
      ;;
  esac

  mkdir -p "${out_dir}"
  cd "${repo_dir}"
  : > "${out_dir}/thread_affinity.txt"
  rm -f "${launch_pid_file}"
  env \
    REPO_DIR="${repo_dir}" \
    RUNNER="${runner}" \
    RUN_LOG="${out_dir}/run.log" \
    PID_FILE="${launch_pid_file}" \
    SAVE_OUTPUT="${out_dir}/${still_name}" \
    MAX_FRAMES="${max_frames}" \
    QUIET=0 \
    bash -lc 'cd "${REPO_DIR}"; echo "${BASHPID}" > "${PID_FILE}"; exec "./scripts/${RUNNER}" > "${RUN_LOG}" 2>&1' &
  local launcher_pid=$!
  echo "${launcher_pid}" > "${out_dir}/launcher_pid"

  for _ in $(seq 1 30); do
    if [[ -s "${launch_pid_file}" ]]; then
      launch_pid="$(cat "${launch_pid_file}")"
      break
    fi
    if ! kill -0 "${launcher_pid}" 2>/dev/null; then
      break
    fi
    sleep 1
  done
  if [[ -z "${launch_pid}" ]]; then
    echo "ERROR: failed to capture demo pid from ${launch_pid_file}" >&2
    return 2
  fi
  local pid="${launch_pid}"
  echo "${pid}" > "${out_dir}/pid"

  for _ in $(seq 1 30); do
    if grep -q 'camera_source=' "${out_dir}/run.log" 2>/dev/null; then
      break
    fi
    if ! kill -0 "${pid}" 2>/dev/null; then
      break
    fi
    sleep 1
  done

  ps -Leo pid,tid,psr,pcpu,comm,args | grep -E '[b]anana_yolo11_demo|[c]am-main|[i]nfer-main|[g]main|[g]dbus|pool-' > "${out_dir}/ps_start.txt" || true
  mpstat -P ALL 1 12 > "${out_dir}/mpstat.txt" 2>&1 &
  local mp_pid=$!
  pidstat -t -p "${pid}" 1 12 > "${out_dir}/pidstat.txt" 2>&1 &
  local pd_pid=$!

  local round
  for round in 1 2 3; do
    sleep 4
    {
      echo "## sample_${round}"
      local task_dir tid name cpus stat
      for task_dir in /proc/"${pid}"/task/*; do
        [[ -d "${task_dir}" ]] || continue
        tid="${task_dir##*/}"
        name="$(tr -d '\0' < "/proc/${pid}/task/${tid}/comm" 2>/dev/null || true)"
        cpus="$(awk '/^Cpus_allowed_list:/ {print $2}' "/proc/${pid}/task/${tid}/status" 2>/dev/null || true)"
        stat="$(ps -L -p "${pid}" -o tid=,psr=,pcpu=,stat=,comm= | awk -v tid="${tid}" '$1==tid {print $0}' || true)"
        echo "tid=${tid} name=${name} cpus=${cpus} stat=${stat}"
      done
    } >> "${out_dir}/thread_affinity.txt"
  done

  wait "${mp_pid}"
  wait "${pd_pid}"
  ps -Leo pid,tid,psr,pcpu,comm,args | grep -E '[b]anana_yolo11_demo|[c]am-main|[i]nfer-main|[g]main|[g]dbus|pool-' > "${out_dir}/ps_end.txt" || true
  wait "${pid}" || true
  tail -n 160 "${out_dir}/run.log" > "${out_dir}/run_tail.txt"
  echo "saved ${out_dir}"
}

if banana_demo_is_board_mode; then
  REPO_DIR="$(banana_demo_board_root)"
  PROFILE="${1:-default}"
  OUT_DIR="${2:-${REPO_DIR}/outputs/affinity_trace_${PROFILE}_$(date +%Y%m%d_%H%M%S)}"
  MAX_FRAMES_VALUE="${3:-}"
  run_board_capture "${REPO_DIR}" "${PROFILE}" "${OUT_DIR}" "${MAX_FRAMES_VALUE}"
  exit 0
fi

source /data/build_scripts/01-env.sh
TARGET="$(banana_demo_host_target)"
BOARD_DIR="$(banana_demo_host_board_dir)"
"${ROOT_DIR}/scripts/deploy_to_banana.sh"

PROFILE="${1:-default}"
STAMP="$(date +%Y%m%d_%H%M%S)"
LOCAL_OUT_DIR="${2:-${ROOT_DIR}/outputs/affinity_trace_${PROFILE}_${STAMP}}"
REMOTE_OUT_DIR="${BOARD_DIR}/outputs/affinity_trace_${PROFILE}_${STAMP}"
MAX_FRAMES_VALUE="${3:-}"
ssh "${TARGET}" "cd '${BOARD_DIR}' && BANANA_DEMO_EXEC_MODE=board ./scripts/capture_camera_affinity.sh '${PROFILE}' '${REMOTE_OUT_DIR}' '${MAX_FRAMES_VALUE}'"
mkdir -p "$(dirname "${LOCAL_OUT_DIR}")"
rsync -a "${TARGET}:${REMOTE_OUT_DIR}/" "${LOCAL_OUT_DIR}/"
echo "saved ${LOCAL_OUT_DIR}"
