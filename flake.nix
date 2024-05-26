{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    poetry2nix.url = "github:bchmnn/poetry2nix";
    naersk.url = "github:nix-community/naersk";
  };

  outputs = {
    systems,
    nixpkgs,
    treefmt-nix,
    poetry2nix,
    naersk,
    ...
  }: let
    # Small tool to iterate over each systems
    eachSystem = f:
      nixpkgs.lib.genAttrs (import systems) (system:
        f (import nixpkgs {
          inherit system;
        }));
    treefmtEval = eachSystem (pkgs:
      treefmt-nix.lib.evalModule pkgs ({...}: {
        projectRootFile = "flake.nix";
        programs = {
          alejandra.enable = true;
          rustfmt.enable = true;
          deadnix.enable = true;
          mix-format.enable = true;
        };
        settings.formatter.alejandra.excludes = ["2configs/vscode/extensions.nix"];
      }));

    naersk' = eachSystem (pkgs: pkgs.callPackage naersk {});
  in {
    devShells = eachSystem (pkgs: let
      inherit (poetry2nix.lib.mkPoetry2Nix {inherit pkgs;}) mkPoetryEnv;
      sqlx-cli = naersk'.${pkgs.system}.buildPackage rec {
        pname = "sqlx-cli";
        version = "0.7.3";

        src = pkgs.fetchCrate {
          inherit pname version;
          sha256 = "sha256-QC1FjBTcbRrWBp12/9CVJ/9L3YMIOAG7k1XqagPv7XQ=";
        };

        buildInputs = [pkgs.openssl];
        nativeBuildInputs = [pkgs.pkg-config];

        # TODO: find better way to force sqlite
        #cargoBuildOptions = s: ["--features" "sqlite"] ++ s;
      };
    in {
      default = pkgs.mkShell {
        packages = [
          pkgs.docker-compose_1
          pkgs.elixir_1_16
          pkgs.cargo
          pkgs.clippy
          pkgs.rust-analyzer
          pkgs.rustfmt
          sqlx-cli
          pkgs.netcat
          pkgs.curl
          (mkPoetryEnv {
            projectDir = ./checker;
            preferWheels = true;
          })
          pkgs.poetry
          pkgs.openssl
          pkgs.php83Packages.composer
          pkgs.php83
          pkgs.graphviz
        ];
        shellHook = ''
          export PROFILE=debug
          alias cw="cargo watch -w build.rs -w src -w templates -w assets  -x \"run\""

          PS1="DEVELOP $PS1"
        '';
      };
    });

    formatter = eachSystem (pkgs: treefmtEval.${pkgs.system}.config.build.wrapper);
  };
}
