// native/build.rs
use std::{env, path::Path};

fn main() {
    // ────────────────────────────────────────────────────────────────
    // 1. Tell the linker where it can *find* libappleai.dylib *now*
    //    (need an absolute path because Cargo builds in a tmp dir)
    // ────────────────────────────────────────────────────────────────
    let manifest_dir = env::var("CARGO_MANIFEST_DIR").expect("no CARGO_MANIFEST_DIR");
    let build_dir = Path::new(&manifest_dir).join("../build");
    println!("cargo:rustc-link-search=native={}", build_dir.display());

    // Link against libappleai.dylib  (lib… prefix + .dylib suffix are implied)
    println!("cargo:rustc-link-lib=dylib=appleai");

    // ────────────────────────────────────────────────────────────────
    // 2. macOS-specific tweaks so the finished .node can *load*
    //    the dylib at run-time, and let Node/Bun resolve N-API symbols
    // ────────────────────────────────────────────────────────────────
    if cfg!(target_os = "macos") {
        // Make the loader search in the directory that contains the .node
        println!("cargo:rustc-link-arg=-Wl,-rpath,@loader_path");

        // Let unresolved symbols be patched in later by Node/Bun
        println!("cargo:rustc-link-arg=-undefined");
        println!("cargo:rustc-link-arg=dynamic_lookup");
    }
}
