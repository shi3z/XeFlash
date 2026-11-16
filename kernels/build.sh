#!/usr/bin/env bash
# Build libxfk.so (SYCL/ESIMD kernels + C ABI runtime).
#   kernels/build.sh [out_dir]      default out_dir: <repo>/build
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
out="${1:-$here/../build}"
mkdir -p "$out"
if ! command -v icpx >/dev/null 2>&1; then
  set +u
  # shellcheck disable=SC1091
  source "${ONEAPI_ROOT:-/opt/intel/oneapi}/setvars.sh" >/dev/null 2>&1 || true
  set -u
fi
# -ffp-contract=off on both the front end and the GPU back end: results must
# not depend on whether IGC decides to fuse a multiply-add.
icpx -fsycl -O2 -std=c++20 -fPIC -shared \
  -ffp-contract=off -fno-fast-math \
  -fsycl-device-code-split=per_kernel \
  -Xsycl-target-backend "-ffp-contract=off" \
  -Wno-deprecated-declarations \
  "$here/runtime.cpp" "$here/gemm/gemm.cpp" "$here/model/model.cpp" \
  -o "$out/libxfk.so"
echo "built $out/libxfk.so"
