with import <nixpkgs> {}; # This should probably be pinned to something. For me it points to 24.05 channel
let
  basePackages = [
    beam28Packages.elixir_1_18
    beam28Packages.erlang
    beam28Packages.elixir-ls
  ];
  PROJECT_ROOT = builtins.toString ./.;

  hooks = ''
    mkdir -p .nix-mix
    mkdir -p .nix-hex
    export MIX_HOME=${PROJECT_ROOT}/.nix-mix
    export HEX_HOME=${PROJECT_ROOT}/.nix-hex
    export PATH=$MIX_HOME/bin:$PATH
    export PATH=$HEX_HOME/bin:$PATH
    export LANG=en_NZ.UTF-8
    export ERL_AFLAGS="-kernel shell_history enabled"
    '';

  in mkShell {
    buildInputs = basePackages;
    shellHook = hooks;
  }