{ stdenv, perl, gnumake, fetchurl, patchShebangs, ... }:

stdenv.mkDerivation {
  pname = "openssl-fips";
  version = "3.0.8";

  src = fetchurl {
    url = "https://www.openssl.org/source/openssl-${version}.tar.gz";
    sha256 = "bBPSvzj98x6sPOKjRwc2c/XWMmM5jx9p0N9KQSU+Sz4=";
  };

  nativeBuildInputs = [ perl gnumake ];
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

    # Move binaries to bin output
    mkdir -p $bin
    if [ -d "$out/bin" ]; then
      cp -r $out/bin/* $bin/
    fi

    # Set library path for fipsinstall
    export LD_LIBRARY_PATH=$out/lib64:$out/lib

    # Install the FIPS module
    $out/bin/openssl fipsinstall -out $out/etc/ssl/fipsmodule.cnf -module $out/lib64/ossl-modules/fips.so

    # Update openssl.cnf to include FIPS configuration
    sed -i \
      -e "s|^# \.include fipsmodule\.cnf|.include $out/etc/ssl/fipsmodule.cnf|" \
      -e 's/^# \(fips = fips_sect\)/\1/' \
      -e 's/^\(default = default_sect\)/# \1/' \
      $out/etc/ssl/openssl.cnf

    # Organize headers and man pages
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

  meta = with stdenv.lib; {
    description = "FIPS-compliant OpenSSL ${version}";
    license = licenses.openssl;
    platforms = platforms.unix;
  };
}
