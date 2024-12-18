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
          # Provide separate outputs for 'out', 'dev', etc.
          default = pkgs.stdenv.mkDerivation rec {
            pname = "openssl-fips";
            version = "3.0.8";

            src = pkgs.fetchurl {
              url = "https://www.openssl.org/source/openssl-${version}.tar.gz";
              sha256 = "bBPSvzj98x6sPOKjRwc2c/XWMmM5jx9p0N9KQSU+Sz4=";
            };

            nativeBuildInputs = [ pkgs.perl pkgs.gnumake ];

            outputs = [ "out" "dev" "man" ];

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
            
              # Create destination directories
              mkdir -p $dev/include
              mkdir -p $man/share/man
            
              # Check if include files exist before moving
              if [ -d "$out/include" ] && [ "$(ls -A $out/include)" ]; then
                mv $out/include/* $dev/include/
              fi
            
              # Check if man pages exist before moving
              if [ -d "$out/share/man" ] && [ "$(ls -A $out/share/man)" ]; then
                mv $out/share/man/* $man/share/man/
              fi
            
              # Remove unnecessary documentation
              rm -rf $out/share/doc
            '';

            postInstall = ''
              # Ensure pkg-config files are set correctly for FIPS OpenSSL
              sed -i "s|prefix=.*|prefix=$out|" $dev/lib/pkgconfig/*.pc
              sed -i "s|exec_prefix=.*|exec_prefix=$out|" $dev/lib/pkgconfig/*.pc
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
