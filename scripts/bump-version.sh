#!/usr/bin/env bash
# Set the version of the crates and the nix packages: bump-version.sh <new version>
set -euo pipefail
new="$1"
old=$(sed -n '/^\[workspace.package\]/,/^\[/s/^version = "\(.*\)"/\1/p' Cargo.toml)
sed -i "/^\[workspace.package\]/,/^\[/s/^version = \"$old\"/version = \"$new\"/" Cargo.toml
sed -i "s/version = \"$old\";/version = \"$new\";/" flake.nix
sed -i "s/^ritsuryo = \"$old\"/ritsuryo = \"$new\"/" crates/ritsuryo/README.md README.md
cargo update --workspace --offline >/dev/null 2>&1 || cargo update --workspace >/dev/null
echo "$old -> $new"
