# Test my functionality by doing:
# openssl version -d
# openssl sha256 /dev/null
# Followed by:
# openssl md5 /dev/null
{
  description = "FIPS-compliant OpenSSL Flake via callPackage";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
  };

  outputs = { self, nixpkgs, ... }:
    let
      supportedSystems = [ "x86_64-linux" "x86_64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          # Use callPackage so that .override and .overrideAttrs are provided automatically
          opensslFips = pkgs.callPackage ./fips-openssl.nix {};
        in {
          default = opensslFips;
        }
      );
    };
}
