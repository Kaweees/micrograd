{ pkgs ? import <nixpkgs> { } }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    zig # Zig compiler
    graphviz # Graphviz
    just # Just runner
    nixfmt-classic # Nix formatter
  ];

  # Shell hook to set up environment
  shellHook = "";
}
