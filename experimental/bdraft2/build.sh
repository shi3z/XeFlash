#!/usr/bin/env bash
# Build libxbd.so from the YASAKANI B60 port's headers (read-only) with the
# flags that port uses for its own library.
#   experimental/bdraft2/build.sh [out_dir]
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
out="${1:-$here/../../build}"
YX="${YASAKANI_XE:-$HOME/yasakani-src/xe}"
JSON="${YASAKANI_JSON:-$HOME/yasakani-src/yasakani/third_party/nlohmann}"
[ -f "$YX/src/draft.hpp" ] || { echo "YASAKANI B60 port not found at $YX" >&2; exit 1; }
mkdir -p "$out"
if ! command -v icpx >/dev/null 2>&1; then
  set +u; source "${ONEAPI_ROOT:-/opt/intel/oneapi}/setvars.sh" >/dev/null 2>&1 || true; set -u
fi
icpx -fsycl -O2 -std=c++20 -ffp-contract=off -fno-fast-math \
  -Xsycl-target-backend "-cl-fp32-correctly-rounded-divide-sqrt -ffp-contract=off" \
  -Wno-deprecated-declarations -I "$YX/src" -I "$JSON" -shared -fPIC \
  "$here/xbd.cpp" -o "$out/libxbd.so"
echo "built $out/libxbd.so"
