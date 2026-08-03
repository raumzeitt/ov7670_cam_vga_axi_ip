#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$ROOT/_env.sh"
make SIM=icarus TEST=sccb_cfg "$@"
