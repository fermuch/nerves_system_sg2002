with import <nixpkgs> {}; # This should probably be pinned to something. For me it points to 24.05 channel
let
  otp = beam28Packages;
  basePackages = [
    otp.elixir_1_18
    otp.erlang
    otp.elixir-ls
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
    '';

  in mkShell {
    buildInputs = basePackages;
    shellHook = hooks;
  }