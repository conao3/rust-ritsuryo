LEAN_RUST ?= lean-rust
WASM_TARGET := target/wasm32-unknown-unknown/release/ritsuryo_wasm.wasm
WEB_DIST ?= dist

.PHONY: all
all: check

# Build the Lean package (proofs included) and regenerate crates/ritsuryo/src/generated/.
.PHONY: generate
generate:
	cd lean && lake build
	$(LEAN_RUST) project generate --lake-dir lean --output-dir crates/ritsuryo/src/generated --modules RitsuryoRs.Api --output text
	rustfmt --edition 2024 crates/ritsuryo/src/generated/mod.rs

.PHONY: check-generated
check-generated: generate
	git diff --exit-code -- crates/ritsuryo/src/generated

.PHONY: fmt-check
fmt-check:
	nix fmt -- --ci

.PHONY: lint
lint:
	cargo clippy --workspace --all-targets -- -D warnings
	cargo clippy -p ritsuryo-wasm --target wasm32-unknown-unknown -- -D warnings

.PHONY: test
test:
	cargo test --workspace

.PHONY: wasm
wasm:
	cargo build -p ritsuryo-wasm --target wasm32-unknown-unknown --release
	wasm-bindgen --target web --out-dir web/pkg --no-typescript $(WASM_TARGET)
	wasm-opt -Oz --enable-bulk-memory --enable-nontrapping-float-to-int -o web/pkg/ritsuryo_wasm_bg.wasm web/pkg/ritsuryo_wasm_bg.wasm

.PHONY: test-wasm
test-wasm: wasm
	node web/test.mjs

.PHONY: web-dist
web-dist: wasm
	mkdir -p $(WEB_DIST)/pkg
	cp web/index.html web/app.js web/style.css $(WEB_DIST)/
	cp web/pkg/ritsuryo_wasm.js web/pkg/ritsuryo_wasm_bg.wasm $(WEB_DIST)/pkg/

.PHONY: check
check: fmt-check lint test test-wasm
