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
      packages.default = pkgs.callPackage ./openssl-fips.nix {};
    };
}