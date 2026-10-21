{
  inputs,
  pkgs,
  ...
}: {
  imports = [
    inputs.devkit.devenvModule
  ];

  packages = [
    inputs.dev-ai-plugins.packages.${pkgs.stdenv.system}.mobile-dev-deps
  ];

  modules.claude = {
    enable = true;
    mempalace.enable = true;
  };

  modules.open-design.enable = true;

  modules.flutter = {
    enable = true;

    mcp.playwright.enable = true;
    skills.enable = true;
  };

  modules.android = {
    enable = true;
    emulator.enable = true;
  };

  enterShell = ''
    # od refuses to register a project location that contains its own data
    # dir, and devkit parks it in $DEVENV_STATE inside the repo.
    export OD_DATA_DIR="$HOME/.local/state/open-design/lull"

    # android/gradlew is generated and gitignored, and its shebang is patched
    # to this machine's /nix/store bash. One that arrives by rsync from
    # another host fails with "No such file or directory" naming gradlew
    # itself. Repoint it only when that interpreter is gone.
    gradlew="$DEVENV_ROOT/android/gradlew"
    if [ -f "$gradlew" ]; then
      interpreter=$(head -1 "$gradlew" | sed -n 's|^#!\([^ ]*\).*|\1|p')
      case "$interpreter" in
        /nix/store/*)
          if [ ! -x "$interpreter" ]; then
            sed -i '1s|.*|#!/usr/bin/env bash|' "$gradlew"
          fi
          ;;
      esac
    fi
  '';
}
