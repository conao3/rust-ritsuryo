# rust-ritsuryo

Japanese statutory periods and taxes for Rust and the browser, computed by the Lean 4 library
[lean-ritsuryo](https://github.com/conao3/lean-ritsuryo), whose functions are proved to compute
what the provisions say. [lean-rs](https://github.com/conao3/lean-rs) compiles the Lean code to
Rust, and the Rust compiles to WebAssembly: the same proved code runs as a Rust crate and in a web
page, with neither Lean nor a server.

- `crates/ritsuryo`: the crate `ritsuryo`. `invoke` runs any subcommand of the `ritsuryo` CLI on
  JSON parameters and returns the JSON the CLI prints; `holiday` and `income_tax` call the
  library functions with Rust types. See [its README](crates/ritsuryo/README.md).
- `crates/ritsuryo-wasm`: the crate for JavaScript (wasm-bindgen): `invoke`, `describe`,
  `isHoliday`.
- `web/`: a page that builds a form for every subcommand from the command table and computes in
  WebAssembly in the browser.
- `lean/`: the Lean package that requires lean-ritsuryo (pinned to a commit) and defines the
  exported functions (`RitsuryoRs/Api.lean`). `crates/ritsuryo/src/generated/` is generated from
  it and committed, so building the crates needs only cargo.

## Use

```
nix run github:conao3/rust-ritsuryo   # serves the web page on http://localhost:8080 (PORT to change)
```

```rust
let out = ritsuryo::invoke(
    "income-tax",
    "compute-tax",
    &serde_json::json!({"TaxYear": 2025, "TaxableIncome": 5_000_000}),
)?;
assert_eq!(out["Result"]["Payable"], 584_500);
```

The parameters are the CLI's, with names in PascalCase (`--taxable-income` is `TaxableIncome`).
A failure carries the CLI's exit code: 252 for a wrong command or parameter, 254 for an input
outside the range the computation handles, 255 otherwise.

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

Apache-2.0
