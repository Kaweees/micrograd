{ pkgs ? import <nixpkgs> { } }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    zig # Zig compiler
    just # Just runner
    nixfmt # Nix formatter
  ];

  # Shell hook to set up environment
  shellHook = "";
}
