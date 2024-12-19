{
  description = "FIPS-compliant OpenSSL Flake";

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

          # Define FIPS OpenSSL with outputs properly handled
          opensslFips = pkgs.stdenv.mkDerivation rec {
            pname = "openssl-fips";
            version = "3.0.8";
            src = pkgs.fetchurl {
              url = "https://www.openssl.org/source/openssl-${version}.tar.gz";
              sha256 = "bBPSvzj98x6sPOKjRwc2c/XWMmM5jx9p0N9KQSU+Sz4=";
            };

            nativeBuildInputs = [ pkgs.perl pkgs.gnumake ];
            outputs = [ "bin" "dev" "out" "man" ];

            configurePhase = ''
              patchShebangs .
              ./Configure enable-fips --prefix=$out --openssldir=$out/etc/ssl
            '';

            buildPhase = ''
              make -j$NIX_BUILD_CORES
            '';

            installPhase = ''
              make install -j$NIX_BUILD_CORES
              
              # Ensure the bin directory exists and has binaries
              mkdir -p $bin $dev/include $man/share/man
              mv $out/bin/* $bin/ || true
              mv $out/include/* $dev/include/ || true
              mv $out/share/man/* $man/share/man/ || true
              rm -rf $out/share/doc
            '';

            meta = with pkgs.lib; {
              description = "FIPS-compliant OpenSSL ${version}";
              license = licenses.openssl;
              platforms = platforms.unix;
            };
          };

        in {
          default = opensslFips;

          # Add `override` for attribute customization
          override = attrs: opensslFips.overrideAttrs (oldAttrs: attrs // {
            outputs = oldAttrs.outputs;
          });
        });
    };
}
