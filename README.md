<p align="center">
  <img src="docs/assets/banner.png" alt="rust-ritsuryo: Japanese statutory periods and taxes for Rust and the browser, compiled from proved Lean 4 code" width="880">
</p>

<p align="center"><strong>Proved Japanese statutory computation, in Rust and the browser</strong></p>

<p align="center">
  <a href="https://crates.io/crates/ritsuryo"><img src="https://img.shields.io/crates/v/ritsuryo" alt="crates.io"></a>
  <a href="https://github.com/conao3/rust-ritsuryo/actions/workflows/ci.yml"><img src="https://github.com/conao3/rust-ritsuryo/actions/workflows/ci.yml/badge.svg?branch=master" alt="CI"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/conao3/rust-ritsuryo" alt="License: Apache-2.0"></a>
  <a href="Cargo.toml"><img src="https://img.shields.io/badge/Rust-edition%202024-orange" alt="Rust edition 2024"></a>
  <a href="lean/lean-toolchain"><img src="https://img.shields.io/badge/Lean-v4.35.0-blue" alt="Lean v4.35.0"></a>
  <a href="https://github.com/conao3/rust-ritsuryo/stargazers"><img src="https://img.shields.io/github/stars/conao3/rust-ritsuryo?style=flat" alt="GitHub stars"></a>
</p>

<p align="center">
  <a href="https://conao3.github.io/rust-ritsuryo/">Web page</a> ·
  <a href="https://crates.io/crates/ritsuryo">crates.io</a> ·
  <a href="#use">Use</a> ·
  <a href="#layout">Layout</a> ·
  <a href="#development">Development</a> ·
  <a href="https://github.com/conao3/lean-ritsuryo">lean-ritsuryo</a>
</p>

# rust-ritsuryo

rust-ritsuryo computes Japanese statutory periods and taxes in Rust and in the browser. The code
comes from the Lean 4 library [lean-ritsuryo](https://github.com/conao3/lean-ritsuryo), which
proves that its functions compute what the provisions say.
[lean-rs](https://github.com/conao3/lean-rs) compiles that Lean code to Rust, and the Rust compiles
to WebAssembly. You run the same proved code as a Rust crate or in a web page, without Lean or a
server.

## Use

### In the browser

Open https://conao3.github.io/rust-ritsuryo/. The page builds a form for each subcommand and
computes in WebAssembly on your machine.

To serve the page yourself:

```
nix run github:conao3/rust-ritsuryo   # serves the web page on http://localhost:8080 (PORT to change)
```

### From Rust

```toml
[dependencies]
ritsuryo = "0.1.0"
```

```rust
let out = ritsuryo::invoke(
    "income-tax",
    "compute-tax",
    &serde_json::json!({"TaxYear": 2025, "TaxableIncome": 5_000_000}),
)?;
assert_eq!(out["Result"]["Payable"], 584_500);
```

`invoke` takes the CLI's parameters, with names in PascalCase (`--taxable-income` is
`TaxableIncome`). A failure carries the CLI's exit code: 252 for a wrong command or parameter, 254
for an input outside the range the computation handles, 255 otherwise.

The crate's [README](crates/ritsuryo/README.md) covers the typed modules `holiday` and
`income_tax`.

## Layout

| Path | Contents |
| --- | --- |
| `crates/ritsuryo` | The crate `ritsuryo`. `invoke` runs any subcommand of the `ritsuryo` CLI on JSON parameters and returns the JSON the CLI prints; `holiday` and `income_tax` call the library functions with Rust types. |
| `crates/ritsuryo-wasm` | The crate for JavaScript (wasm-bindgen): `invoke`, `describe`, `isHoliday`. |
| `web/` | A page that builds a form for every subcommand from the command table and computes in WebAssembly in the browser. |
| `lean/` | The Lean package that requires lean-ritsuryo (pinned to a commit) and defines the exported functions (`RitsuryoRs/Api.lean`). |

`make generate` writes `crates/ritsuryo/src/generated/` from the Lean package, and the repository
commits that output, so you build the crates with cargo alone.

## Development

```
nix develop
make check            # format, clippy (native and wasm32), tests, the wasm module under node
make generate         # build the Lean package (proofs included) and regenerate the Rust
make check-generated  # generate, then fail if the committed Rust differs
make web-dist         # the web page in dist/ (nix build .#web builds the same)
```

To follow a new lean-ritsuryo, change `rev` in `lean/lakefile.toml`, run `lake update` in `lean/`,
and `make generate`.

## License

Apache-2.0. See [LICENSE](LICENSE).
