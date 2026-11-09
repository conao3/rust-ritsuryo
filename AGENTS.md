# AGENTS.md

## Layout

- `lean/RitsuryoRs/Api.lean` defines the functions exported to Rust; its public definitions are
  the roots of the generated module. Helpers are `private` so that they are not exported.
- `crates/ritsuryo/src/generated/` is the output of `make generate` (lean-rust `project
  generate`). Do not edit it by hand; regenerate and commit it with the Lean change.
- `crates/ritsuryo` wraps the generated functions in a Rust API; `crates/ritsuryo-wasm` exposes
  them to JavaScript; `web/` is the page and `web/test.mjs` its node test.

## Verification

- `nix develop --command make check`: treefmt check, clippy for the host and for
  `wasm32-unknown-unknown`, `cargo test`, and the wasm module under node.
- `nix develop --command make check-generated`: the Lean build (proofs included) and the
  generated Rust match the committed files.
- `nix build` (the web page) and `nix build .#web`.
- UI changes: serve `dist/` (`make web-dist`) and check the page in a browser, including the
  console.

## Conventions

- Commit messages, comments and docs in English; the web page's text in Japanese.
- The Lean toolchain and the `lean-rust` CLI come from the dev shell (nixpkgs `lean4` and the
  lean-rs flake), so the `.olean` files and the CLI agree.
