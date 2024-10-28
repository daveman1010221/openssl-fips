{
  description = "FIPS-compliant OpenSSL Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
  };

  outputs = { self, nixpkgs, ... }:
    let
      pkgs = import nixpkgs { };
    in
    {
      defaultPackage.x86_64-linux = pkgs.callPackage ./openssl-fips.nix {};
    };
}