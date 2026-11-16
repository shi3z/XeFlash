//! Builds the SYCL/ESIMD kernel library (kernels/build.sh -> build/libxfk.so)
//! and links it. Binaries find libxfk.so and the oneAPI runtime at run time
//! through LD_LIBRARY_PATH; use scripts/b60run, which also takes the GPU lock.
use std::path::PathBuf;
use std::process::Command;

fn main() {
    let root = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../..").canonicalize().unwrap();
    let kernels = root.join("kernels");
    let out = root.join("build");
    println!("cargo:rerun-if-changed={}", kernels.display());
    let status = Command::new("bash")
        .arg(kernels.join("build.sh"))
        .arg(&out)
        .status()
        .expect("failed to run kernels/build.sh");
    assert!(status.success(), "kernels/build.sh failed");
    println!("cargo:rustc-link-search=native={}", out.display());
    println!("cargo:rustc-link-lib=dylib=xfk");
}
