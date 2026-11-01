#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# The pipeline verifies config/toolchain.json against actual Flutter/Dart output.
# Every required stage retains current-run logs/reports and missing acceptance fails.
exec python3 tool/verify_pipeline.py --scope desktop-full "$@"
