with import <nixpkgs> {}; # This should probably be pinned to something. For me it points to 24.05 channel
let
  otp = beam28Packages;
  basePackages = [
    otp.elixir_1_18
    otp.erlang
    otp.elixir-ls

    # build deps for nerves
    pkg-config
    fwup
    squashfsTools

    # for ash/phoenix
    inotify-tools
    watchman
  ];
  PROJECT_ROOT = builtins.toString ./.;

  hooks = ''
    mkdir -p .nix-mix
    mkdir -p .nix-hex
    export MIX_HOME=${PROJECT_ROOT}/.nix-mix
    export HEX_HOME=${PROJECT_ROOT}/.nix-hex
    export MIX_PATH="${otp.hex}/lib/erlang/lib/hex/ebin"
    export PATH=$MIX_HOME/bin:$HEX_HOME/bin:$PATH
    export PATH=$HEX_HOME/bin:$PATH
    export LANG=en_NZ.UTF-8
    export ERL_AFLAGS="-kernel shell_history enabled"

    mix local.hex --force
    mix archive.install hex nerves_bootstrap --force
    mix archive.install hex phx_new --force

    export MIX_TARGET=nerves_system_sg2002
    '';

  in mkShell {
    buildInputs = basePackages;
    shellHook = hooks;
  }
