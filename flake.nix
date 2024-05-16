{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    treefmt-nix.url = "github:numtide/treefmt-nix";
  };

  outputs = {
    systems,
    nixpkgs,
    treefmt-nix,
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
  in {
    devShells = eachSystem (pkgs: {
      default = pkgs.mkShell {
        packages = [
          pkgs.docker-compose_1
          pkgs.elixir_1_16
          pkgs.cargo
          pkgs.netcat
          pkgs.enochecker-test
          pkgs.curl
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
