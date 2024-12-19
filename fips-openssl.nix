{ stdenv, lib, perl, gnumake, fetchurl, ... }:

stdenv.mkDerivation {
  pname = "openssl-fips";
  version = "3.0.8";

  src = fetchurl {
    url = "https://www.openssl.org/source/openssl-3.0.8.tar.gz";
    sha256 = "bBPSvzj98x6sPOKjRwc2c/XWMmM5jx9p0N9KQSU+Sz4=";
  };

  nativeBuildInputs = [ perl gnumake ];

  # Add 'doc' output like the original does (and possibly 'etc' if needed)
  outputs = [ "bin" "dev" "out" "man" "doc" ];

  # Configure phase similar to original
  configurePhase = ''
    patchShebangs .
    ./Configure enable-fips --prefix=$out --openssldir=$out/etc/ssl --libdir=lib
  '';

  buildPhase = ''
    make -j$NIX_BUILD_CORES
  '';

  installPhase = ''
    make install -j$NIX_BUILD_CORES

    # Reorganize outputs, just like original openssl package does

    # Binaries: move to bin output
    mkdir -p $bin/bin
    mv $out/bin/* $bin/bin/ || true
    rmdir $out/bin || true

    # Headers and pkg-config files: dev output
    mkdir -p $dev/include $dev/lib/pkgconfig
    mv $out/include/* $dev/include/ || true
    mv $out/lib/pkgconfig/* $dev/lib/pkgconfig/ || true

    # Man pages: man output
    mkdir -p $man/share/man
    if [ -d "$out/share/man" ]; then
      mv $out/share/man/* $man/share/man/
      rmdir $out/share/man
    fi

    # Documentation: doc output (HTML docs, etc.)
    # The original puts HTML docs under $doc/share/doc/openssl/html/
    mkdir -p $doc/share/doc/openssl/html
    if [ -d "$out/share/doc" ]; then
      if [ -d "$out/share/doc/openssl/html" ]; then
        mv $out/share/doc/openssl/html/* $doc/share/doc/openssl/html/
      fi
      rm -rf $out/share/doc
    fi

    # Clean up empty directories
    find $out -type d -empty -delete

    # Set library path for fipsinstall
    export LD_LIBRARY_PATH=$out/lib

    # Install the FIPS module
    $bin/bin/openssl fipsinstall -out $out/etc/ssl/fipsmodule.cnf -module $out/lib/ossl-modules/fips.so

    # Update openssl.cnf to include FIPS configuration
    sed -i \
      -e "s|^# \.include fipsmodule\.cnf|.include $out/etc/ssl/fipsmodule.cnf|" \
      -e 's/^# \(fips = fips_sect\)/\1/' \
      -e 's/^\(default = default_sect\)/# \1/' \
      $out/etc/ssl/openssl.cnf

    # Cleanup empty directories if any remain
    find $out -type d -empty -delete
  '';

  postInstall = ''
    # Adjust pkg-config files to point to $out
    sed -i "s|prefix=.*|prefix=$out|" $dev/lib/pkgconfig/*.pc
    sed -i "s|exec_prefix=.*|exec_prefix=$out|" $dev/lib/pkgconfig/*.pc

    # Set rpath so openssl can run without LD_LIBRARY_PATH
    patchelf --set-rpath $out/lib $bin/bin/openssl
  '';

  meta = with lib; {
    description = "FIPS-compliant OpenSSL ${version}";
    license = licenses.openssl;
    platforms = platforms.unix;
  };
}
