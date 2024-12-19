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

          # Common logic for FIPS OpenSSL
          commonFips = { version, sha256 }:
            pkgs.stdenv.mkDerivation rec {
              pname = "openssl-fips";
              inherit version;

              src = pkgs.fetchurl {
                url = "https://www.openssl.org/source/openssl-${version}.tar.gz";
                inherit sha256;
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
                # Install the libraries
                make install -j$NIX_BUILD_CORES

                # Ensure binaries are copied to the bin output
                mkdir -p $bin
                if [ -d "$out/bin" ]; then
                  cp -r $out/bin/* $bin/
                fi

                # Ensure the FIPS module is installed correctly
                export LD_LIBRARY_PATH=$out/lib64:$out/lib
                $out/bin/openssl fipsinstall -out $out/etc/ssl/fipsmodule.cnf -module $out/lib64/ossl-modules/fips.so

                # Fix the openssl.cnf file to include the FIPS configuration
                sed -i \
                  -e "s|^# \.include fipsmodule\.cnf|.include $out/etc/ssl/fipsmodule.cnf|" \
                  -e 's/^# \(fips = fips_sect\)/\1/' \
                  -e 's/^\(default = default_sect\)/# \1/' \
                  $out/etc/ssl/openssl.cnf

                # Organize include and man pages
                mkdir -p $dev/include
                mkdir -p $man/share/man
                if [ -d "$out/include" ] && [ "$(ls -A $out/include)" ]; then
                  mv $out/include/* $dev/include/
                fi
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

          # Define FIPS versions
          opensslFips3_0_8 = commonFips {
            version = "3.0.8";
            sha256 = "bBPSvzj98x6sPOKjRwc2c/XWMmM5jx9p0N9KQSU+Sz4=";
          };
        in
        {
          default = opensslFips3_0_8;

          # Include override functionality for extensions if needed
          override = attrs: commonFips (attrs // { version = opensslFips3_0_8.version; sha256 = opensslFips3_0_8.sha256; });

        }
      );
    };
}
