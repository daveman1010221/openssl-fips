{
  description = "FIPS-compliant OpenSSL Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
  };

  outputs = { self, nixpkgs, ... }: let
    supportedSystems = [ "x86_64-linux" "x86_64-darwin" ];
    forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

    # Centralized logic for building OpenSSL
    commonFips = { system, version, sha256, patches ? [] }: let
      pkgs = import nixpkgs { inherit system; };
    in
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
        
          # Ensure the bin directory exists
          mkdir -p $bin
          if [ -d "$out/bin" ]; then
            mv $out/bin/* $bin/ || true
          fi
        
          # Set up FIPS module
          export LD_LIBRARY_PATH=$out/lib64:$out/lib
          if [ -f $out/lib64/ossl-modules/fips.so ]; then
            $bin/openssl fipsinstall -out $out/etc/ssl/fipsmodule.cnf -module $out/lib64/ossl-modules/fips.so
          else
            echo "FIPS module not found" >&2
            exit 1
          fi
        
          # Update openssl.cnf
          if [ -f $out/etc/ssl/openssl.cnf ]; then
            sed -i \
              -e "s|^# \.include fipsmodule\.cnf|.include $out/etc/ssl/fipsmodule.cnf|" \
              -e 's/^# \(fips = fips_sect\)/\1/' \
              -e 's/^\(default = default_sect\)/# \1/' \
              $out/etc/ssl/openssl.cnf
          else
            echo "openssl.cnf not found" >&2
            exit 1
          fi
        
          # Move include and man pages
          mkdir -p $dev/include
          mkdir -p $man/share/man
          mv $out/include/* $dev/include/ || true
          mv $out/share/man/* $man/share/man/ || true
        
          # Remove unnecessary files
          rm -rf $out/share/doc
        '';


        meta = with pkgs.lib; {
          description = "FIPS-compliant OpenSSL ${version}";
          license = licenses.openssl;
          platforms = supportedSystems;
        };
      };

  in {
    packages = forAllSystems (system: {
      default = commonFips {
        inherit system;
        version = "3.0.8";
        sha256 = "bBPSvzj98x6sPOKjRwc2c/XWMmM5jx9p0N9KQSU+Sz4=";
      };

      # Provide `override` for custom attributes
      override = attrs: commonFips {
        inherit system;
        version = attrs.version or "3.0.8";
        sha256 = attrs.sha256 or "bBPSvzj98x6sPOKjRwc2c/XWMmM5jx9p0N9KQSU+Sz4=";
        patches = attrs.patches or [];
      };
    });
  };
}
