# ritsuryo

Japanese statutory periods and taxes, computed by the Lean 4 library
[lean-ritsuryo](https://github.com/conao3/lean-ritsuryo), whose functions are proved to compute
what the provisions say. [lean-rs](https://github.com/conao3/lean-rs) compiles the Lean code to
Rust, so this crate builds with cargo alone: it needs neither Lean nor a C compiler.

```rust
use serde_json::json;

let out = ritsuryo::invoke(
    "income-tax",
    "compute-tax",
    &json!({"TaxYear": 2025, "TaxableIncome": 5_000_000}),
)
.unwrap();
assert_eq!(out["Result"]["IncomeTax"], 572_500);

assert!(ritsuryo::holiday::is_holiday(2026, 11, 23));
assert_eq!(ritsuryo::income_tax::compute(2025, 5_000_000, 0, 0).payable, 584_500);
```

`invoke` runs any subcommand of the `ritsuryo` CLI, with the parameters as a JSON object keyed by
the CLI's parameter names in PascalCase, and returns the JSON the CLI prints. `describe` gives the
command table. The modules `holiday` and `income_tax` call the library functions with Rust types.
