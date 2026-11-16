//! With the `bdraft2` feature, build experimental/bdraft2 (libxbd.so) and link it.
use std::path::PathBuf;
use std::process::Command;

fn main() {
    if std::env::var_os("CARGO_FEATURE_BDRAFT2").is_none() {
        return;
    }
    let root = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../..").canonicalize().unwrap();
    let src = root.join("experimental/bdraft2");
    let out = root.join("build");
    println!("cargo:rerun-if-changed={}", src.display());
    let ok = Command::new("bash").arg(src.join("build.sh")).arg(&out).status().map(|s| s.success()).unwrap_or(false);
    assert!(ok, "experimental/bdraft2/build.sh failed");
    println!("cargo:rustc-link-search=native={}", out.display());
    println!("cargo:rustc-link-lib=dylib=xbd");
}
