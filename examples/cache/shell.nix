{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    elixir_1_14
    elixir_ls
  ];
}

