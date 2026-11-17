# AGENTS.md

## Layout

- `lean/RitsuryoRs/Api.lean` defines the functions exported to Rust; its public definitions are
  the roots of the generated module. Helpers are `private` so that they are not exported.
- `crates/ritsuryo/src/generated/` is the output of `make generate` (leanfran `project
  generate`). Do not edit it by hand; regenerate and commit it with the Lean change.
- `crates/ritsuryo` wraps the generated functions in a Rust API; `crates/ritsuryo-wasm` exposes
  them to JavaScript; `web/` is the page and `web/test.mjs` its node test.

## Lean and Rust

Lean defines command dispatch, input validation, holiday lookup and statutory tax computation;
Rust handles API types, JSON conversion and WebAssembly integration. The dependency
`lean-ritsuryo` supplies the statutory specifications and proofs. The API theorems in
`lean/RitsuryoRs/Api.lean` state properties of the exported functions themselves:

- `invoke_unknown_command`: an unknown command rendered as JSON returns usage code 252.
- `isHoliday_iff_mem_holidays`: a date is a holiday exactly when the exported list contains it.
- `holidayYearInRange_iff`: supported years are exactly 1955 through 2027, inclusive.
- `holidays_length`: conversion to API rows preserves the number of holiday entries.
- `incomeTax_bases`: each taxable base is a multiple of 1,000 yen at most the input and less
  than 1,000 yen below it.
- `incomeTax_ordinary_spec`: ordinary income tax agrees with the statutory progressive sum.
- `incomeTax_timber_spec`: timber income tax agrees with the statutory five-part calculation.

`audit/` is a separate Lake package requiring `../lean` and a pinned lean-assay revision.
It audits `invoke`, `isHoliday`, `holidayYearInRange`, `holidays` and `incomeTax`.
The audit generates 14 mutants: 10 killed, 0 holes, 0 untested, 4 equivalent, 0 timed out
and 0 stillborn (failed elaboration or execution). Per function:

| Function | Mutants | Killed | Equivalent | Stillborn |
|---|---:|---:|---:|---:|
| `invoke` | 1 | 1 | 0 | 0 |
| `isHoliday` | 3 | 3 | 0 | 0 |
| `holidayYearInRange` | 7 | 3 | 4 | 0 |
| `holidays` | 2 | 2 | 0 | 0 |
| `incomeTax` | 1 | 1 | 0 | 0 |

The year generator samples 1951–2031, covering every supported year and both boundaries;
the natural-number generator mixes 0–32, amounts up to 50 million yen and rounding, tax-rate
and surtax-year boundaries. The theorems quantify over all inputs; these generators control
only the mutation audit. The audit derives `Inhabited` and `DecidableEq` for the dependency's
`Tax.Income.Result`, enabling a constant-result mutant and output comparison. Equivalent means
equal outputs on the inputs tried.

`describe` stays outside the audit: it serializes the fixed command and parameter metadata,
with no separate computational policy to specify beyond reproducing that table and its JSON
layout. `#assay RitsuryoRs.Api.describe` reports `no theorem mentions` and stops before
producing mutants. `web/test.mjs` parses its JSON and checks the command table through the
built WebAssembly module.

Run `lake -d audit build --wfail` in the dev shell to check the proofs and their audit.
A missing theorem, a function whose mutants all survive, a hole or vacuous hypotheses fails
this check. Add a useful theorem and an audit entry with each computational API function.

## Verification

- `nix develop --command make check`: treefmt check, Lean proofs and their lean-assay audit,
  clippy for the host and for `wasm32-unknown-unknown`, `cargo test`, and the wasm module under node.
- `nix develop --command make check-generated`: the Lean build (proofs included) and the
  generated Rust match the committed files.
- `nix build` (the web page) and `nix build .#web`.
- UI changes: serve `dist/` (`make web-dist`) and check the page in a browser, including the
  console.

## Conventions

- Commit messages, comments and docs in English; the web page's text in Japanese.
- The Lean toolchain and the `leanfran` CLI come from the dev shell (nixpkgs `lean4` and the
  lean-leanfran flake), so the `.olean` files and the CLI agree.
