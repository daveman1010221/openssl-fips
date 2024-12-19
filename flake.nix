{
  description = "FIPS-compliant OpenSSL Flake with .override support";

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

          commonFips = { version, sha256 }:
            pkgs.stdenv.mkDerivation {
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

              buildPhase = "make -j$NIX_BUILD_CORES";

              installPhase = ''
                make install -j$NIX_BUILD_CORES
                mkdir -p $bin
                if [ -d "$out/bin" ]; then
                  cp -r $out/bin/* $bin/
                fi

                export LD_LIBRARY_PATH=$out/lib64:$out/lib
                $out/bin/openssl fipsinstall -out $out/etc/ssl/fipsmodule.cnf -module $out/lib64/ossl-modules/fips.so

                sed -i \
                  -e "s|^# \.include fipsmodule\.cnf|.include $out/etc/ssl/fipsmodule.cnf|" \
                  -e 's/^# \(fips = fips_sect\)/\1/' \
                  -e 's/^\(default = default_sect\)/# \1/' \
                  $out/etc/ssl/openssl.cnf

                mkdir -p $dev/include $man/share/man
                if [ -d "$out/include" ] && [ "$(ls -A $out/include)" ]; then
                  mv $out/include/* $dev/include/
                fi
                if [ -d "$out/share/man" ] && [ "$(ls -A $out/share/man)" ]; then
                  mv $out/share/man/* $man/share/man/
                fi

                rm -rf $out/share/doc
              '';

              postInstall = ''
                sed -i "s|prefix=.*|prefix=$out|" $dev/lib/pkgconfig/*.pc
                sed -i "s|exec_prefix=.*|exec_prefix=$out|" $dev/lib/pkgconfig/*.pc
              '';

              meta = with pkgs.lib; {
                description = "FIPS-compliant OpenSSL ${version}";
                license = licenses.openssl;
                platforms = platforms.unix;
              };
            };

          opensslFips3_0_8 = commonFips {
            version = "3.0.8";
            sha256 = "bBPSvzj98x6sPOKjRwc2c/XWMmM5jx9p0N9KQSU+Sz4=";
          };

          # Add `.override` attribute manually
          opensslFipsWithOverride = opensslFips3_0_8 // {
            override = newAttrs: opensslFips3_0_8.overrideAttrs (old: old // newAttrs);
          };

        in {
          default = opensslFipsWithOverride;
        }
      );
    };
}
