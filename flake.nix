{
  description = "FIPS-compliant OpenSSL Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
  };

  outputs = { self, nixpkgs, ... }:
    let
      supportedSystems = [ "x86_64-linux" "x86_64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      lib = nixpkgs.lib;
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          default = pkgs.stdenv.mkDerivation rec {
            pname = "openssl-fips";
            version = "3.0.8";

            src = pkgs.fetchurl {
              url = "https://www.openssl.org/source/openssl-${version}.tar.gz";
              sha256 = "bBPSvzj98x6sPOKjRwc2c/XWMmM5jx9p0N9KQSU+Sz4=";
            };

            nativeBuildInputs = [ pkgs.perl pkgs.gnumake ];

            configurePhase = ''
              patchShebangs .
              ./Configure enable-fips --prefix=$out --openssldir=$out/etc/ssl
            '';

            buildPhase = ''
              make -j$NIX_BUILD_CORES
            '';

            installPhase = ''
              # Install the libraries
              make install -j$NIX_BUILD_CORES

              # Need to fixup the files so that when installed, the MAC is correct
              # if you do not do this, the FIPS module will not load.
              runHook fixupPhase

              # Set the library path so that the FIPS module can be installed
              export LD_LIBRARY_PATH=$out/lib64:$out/lib

              # Install the FIPS module
              $out/bin/openssl fipsinstall -out $out/etc/ssl/fipsmodule.cnf -module $out/lib64/ossl-modules/fips.so

              # Fix the openssl.cnf file to include the fipsmodule.cnf file and enable FIPS mode
              sed -i \
                -e "s|^# \.include fipsmodule\.cnf|.include $out/etc/ssl/fipsmodule.cnf|" \
                -e 's/^# \(fips = fips_sect\)/\1/' \
                -e 's/^\(default = default_sect\)/# \1/' \
                $out/etc/ssl/openssl.cnf

              # Remove the non-man docs (man docs are stored in /share/man)
              rm -rf $out/share/doc
            '';

            meta = with pkgs.lib; {
              description = "FIPS-compliant OpenSSL ${version}";
              license = licenses.openssl;
              platforms = platforms.unix;
            };
          };
        }
      );
    };
}
