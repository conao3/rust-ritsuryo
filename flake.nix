{
  description = "Japanese statutory computation with Lean 4 proofs, compiled to Rust and WebAssembly";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    lean-rs = {
      url = "github:conao3/lean-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ flake-parts, nixpkgs, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];

      imports = [ inputs.treefmt-nix.flakeModule ];

      perSystem =
        { system, config, ... }:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ inputs.rust-overlay.overlays.default ];
          };
          rust = pkgs.rust-bin.stable.latest.default.override {
            extensions = [
              "clippy"
              "rust-src"
              "rustfmt"
            ];
            targets = [ "wasm32-unknown-unknown" ];
          };
          rustPlatform = pkgs.makeRustPlatform {
            cargo = rust;
            rustc = rust;
          };
          src = pkgs.lib.cleanSource ./.;
        in
        {
          _module.args.pkgs = pkgs;

          packages.web = rustPlatform.buildRustPackage {
            pname = "ritsuryo-web";
            version = "0.1.0";
            inherit src;
            cargoLock.lockFile = ./Cargo.lock;
            nativeBuildInputs = [
              pkgs.wasm-bindgen-cli
              pkgs.binaryen
              pkgs.gnumake
            ];
            buildPhase = ''
              runHook preBuild
              make web-dist WEB_DIST=$out
              runHook postBuild
            '';
            installPhase = "true";
            doCheck = false;
          };

          packages.default = pkgs.writeShellApplication {
            name = "ritsuryo-web";
            runtimeInputs = [ pkgs.static-web-server ];
            text = ''
              exec static-web-server --root ${config.packages.web} --port "''${PORT:-8080}" "$@"
            '';
            meta.description = "Serve the ritsuryo web page, which computes in WebAssembly";
          };

          devShells.default = pkgs.mkShell {
            packages = [
              rust
              pkgs.lean4
              inputs.lean-rs.packages.${system}.lean-rust
              pkgs.wasm-bindgen-cli
              pkgs.binaryen
              pkgs.nodejs
              pkgs.gnumake
            ];
          };

          treefmt = {
            programs.nixfmt.enable = true;
            programs.rustfmt = {
              enable = true;
              package = rust;
              edition = "2024";
            };
            settings.formatter.rustfmt.excludes = [ "crates/ritsuryo/src/generated/**" ];
          };
        };
    };
}
