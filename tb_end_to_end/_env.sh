#!/usr/bin/env bash
# Shared cocotb runner setup: oss-cad-suite tools + local pydeps (cocotbext-axi).
set -euo pipefail

TB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$TB_ROOT"

if [[ -n "${VIRTUAL_ENV:-}" ]]; then
  PATH="$(printf '%s' "$PATH" | tr ':' '\n' | grep -v '/\.venv/' | paste -sd: -)"
  export PATH
  unset VIRTUAL_ENV
fi
unset PYTHONHOME

if [[ -d /Applications/oss-cad-suite/bin ]]; then
  if [[ -f /Applications/oss-cad-suite/environment ]]; then
    set +u
    # shellcheck disable=SC1091
    source /Applications/oss-cad-suite/environment
    set -u
  else
    export PATH="/Applications/oss-cad-suite/bin:$PATH"
  fi
  unset PYTHONHOME
fi

if ! command -v cocotb-config >/dev/null 2>&1; then
  if [[ ! -d .venv ]]; then
    python3 -m venv .venv
  fi
  .venv/bin/pip install -q -r requirements.txt
  # shellcheck disable=SC1091
  source .venv/bin/activate
  unset PYTHONHOME
fi

PYDEPS="$TB_ROOT/pydeps"
if [[ ! -d "$PYDEPS/cocotbext" ]]; then
  mkdir -p "$PYDEPS"
  PIP=pip3
  if command -v tabbypy3 >/dev/null 2>&1; then
    PIP="tabbypy3 -m pip"
  fi
  $PIP install -q --target "$PYDEPS" --no-deps "cocotbext-axi>=0.1.28" "cocotb-bus>=0.2"
  rm -rf "$PYDEPS/cocotb" "$PYDEPS/cocotb-"*.dist-info 2>/dev/null || true
fi

# Include cam_ip/tb so we can import ov7670_bfm
CAM_TB="$(cd "$TB_ROOT/../cam_ip/tb" && pwd)"
export PYTHONPATH="${TB_ROOT}:${CAM_TB}:${PYDEPS}${PYTHONPATH:+:${PYTHONPATH}}"
