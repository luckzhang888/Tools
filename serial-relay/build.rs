// build.rs — Read baud rate from Cargo.toml metadata at compile time.
//
// Looks up [package.metadata].baud_rate in Cargo.toml and
// exposes it to the main crate as the BAUD_RATE env var.
//
// Usage in main.rs:
//     const BAUD_RATE: u32 = env!("BAUD_RATE").parse().unwrap();

use std::env;
use std::fs;
use std::path::Path;

fn main() {
    let manifest_dir = env::var("CARGO_MANIFEST_DIR").expect("CARGO_MANIFEST_DIR not set");
    let cargo_toml_path = Path::new(&manifest_dir).join("Cargo.toml");
    let cargo_toml = fs::read_to_string(&cargo_toml_path).expect("Failed to read Cargo.toml");

    // Parse the TOML and extract [package.metadata].baud_rate
    let parsed: toml::Table =
        toml::from_str(&cargo_toml).expect("Failed to parse Cargo.toml as TOML");

    let baud_rate = parsed
        .get("package")
        .and_then(|p| p.get("metadata"))
        .and_then(|m| m.get("baud_rate"))
        .and_then(|v| v.as_integer())
        .unwrap_or(9600);

    println!("cargo:rustc-env=BAUD_RATE={baud_rate}");

    // Re-run build.rs when Cargo.toml changes
    println!("cargo:rerun-if-changed=Cargo.toml");
}
