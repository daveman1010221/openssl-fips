{
  description = "FIPS-compliant OpenSSL Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
  };

  outputs = { self, nixpkgs, ... }:
    let
      pkgs = import nixpkgs { system = "x86_64-linux"; };
    in
    {
      defaultPackage.x86_64-linux = pkgs.callPackage ./openssl-fips.nix {
        lib = pkgs.lib;
        gnumake = pkgs.gnumake;
        gcc = pkgs.gcc;
        perl = pkgs.perl;
        coreutils = pkgs.coreutils;
      };
    };
}