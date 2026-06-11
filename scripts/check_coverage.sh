#!/usr/bin/env bash
# scripts/check_coverage.sh
#
# Valida que la cobertura de tests de un directorio cumple un umbral.
# Usa el lcov.info producido por `flutter test --coverage`.
#
# Usage:
#   bash scripts/check_coverage.sh [lcov_file] [target_dir] [threshold]
#
# Defaults:
#   lcov_file  = coverage/lcov.info
#   target_dir = lib/core/security
#   threshold  = 50
#
# Exit codes:
#   0  Cobertura >= umbral
#   1  Cobertura < umbral, O lcov sin archivos del target
#   2  lcov no existe

set -euo pipefail

LCOV_FILE="${1:-coverage/lcov.info}"
TARGET_DIR="${2:-lib/core/security}"
THRESHOLD="${3:-50}"

if [ ! -f "$LCOV_FILE" ]; then
  echo "Error: $LCOV_FILE no existe. Correr 'flutter test --coverage' primero." >&2
  exit 2
fi

awk \
  -v target="$TARGET_DIR" \
  -v threshold="$THRESHOLD" '
  BEGIN { total_lf = 0; total_lh = 0 }
  /^SF:/ { current = substr($0, 4); gsub(/\\/, "/", current) }
  /^LF:/ { lf = substr($0, 4) + 0 }
  /^LH:/ { lh = substr($0, 4) + 0 }
  /^end_of_record/ {
    if (current ~ target) {
      total_lf += lf
      total_lh += lh
    }
  }
  END {
    if (total_lf == 0) {
      printf "FAIL: ningun archivo bajo %s encontrado en %s\n", target, FILENAME
      exit 1
    }
    pct = (total_lh / total_lf) * 100
    printf "Coverage %s: %d/%d lineas (%.1f%%)\n", target, total_lh, total_lf, pct
    if (pct + 0.0001 < threshold) {
      printf "FAIL: %.1f%% < %d%% umbral\n", pct, threshold
      exit 1
    }
    printf "OK: %.1f%% >= %d%% umbral\n", pct, threshold
    exit 0
  }
' "$LCOV_FILE"
