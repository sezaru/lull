{
  description = "Lull: ad-free controller for the Pulsetto vagus nerve stimulator";

  inputs = {
    devenv.url = "github:cachix/devenv";

    nixpkgs.url = "github:cachix/devenv-nixpkgs/rolling";

    flake-utils.url = "github:numtide/flake-utils";

    devkit.url = "github:sezaru/nix-devkit";

    dev-ai-plugins.url = "github:Hexhound/dev-ai-plugins";
  };

  nixConfig = {
    extra-trusted-public-keys = "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=";
    extra-substituters = "https://devenv.cachix.org";
  };

  outputs = {
    devenv,
    nixpkgs,
    flake-utils,
    ...
  } @ inputs:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in {
      devShells.default = devenv.lib.mkShell {
        inherit inputs pkgs;
        modules = [
          ./.nix/devenv.nix
        ];
      };
    });
}
