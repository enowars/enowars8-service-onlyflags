{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = {
    self,
    systems,
    nixpkgs,
  }: let
    # Small tool to iterate over each systems
    eachSystem = f:
      nixpkgs.lib.genAttrs (import systems) (system:
        f (import nixpkgs {
          inherit system;
        }));
  in {
    devShells = eachSystem (pkgs: {
      default = pkgs.mkShell {
        packages = [
          pkgs.elixir_1_16
        ];
        shellHook = ''
          export PROFILE=debug
          alias cw="cargo watch -w build.rs -w src -w templates -w assets  -x \"run\""

          PS1="DEVELOP $PS1"
        '';
      };
    });
  };
}
