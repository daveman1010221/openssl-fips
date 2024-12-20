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
  # "out" creates /etc/ssl/misc and /lib/engines-3 and /lib/ossl-modules
  # "bin" creates /bin, with just two binaries
  outputs = [ "bin" "dev" "out" "man" "doc" ];

  # Configure phase similar to original
  configurePhase = ''
    patchShebangs .
    ./Configure enable-fips --prefix=$out --openssldir=$out/etc/ssl --libdir=$out/lib
  '';

  buildPhase = ''
    make -j$NIX_BUILD_CORES
  '';

  makeFlags = [
    "MANDIR=$(man)/share/man"
    "MANSUFFIX=ssl"
  ];

  enableParallelBuilding = true;

  installPhase = ''
    make install -j$NIX_BUILD_CORES

    # Binaries get move to the 'bin' output, but their DLLs stay put.
    mkdir -p $bin/bin
    mv $out/bin/* $bin/bin/ || true
    rmdir $out/bin || true
  '';

  postFixup = ''
    # Set rpath so openssl can run without LD_LIBRARY_PATH
    # patchelf --shrink-rpath $bin/bin/openssl
    # patchelf --shrink-rpath $bin/bin/c_rehash

    # patchelf --set-rpath $out/lib:$out/lib/engines-3:$out/lib/ossl-modules $bin/bin/openssl
    # patchelf --set-rpath $out/lib:$out/lib/engines-3:$out/lib/ossl-modules $bin/bin/c_rehash

    # Adjust pkg-config files to point to $out
    if [ -d "$dev/lib/pkgconfig" ]; then
      sed -i "s|prefix=.*|prefix=$out|" $dev/lib/pkgconfig/*.pc
      sed -i "s|exec_prefix=.*|exec_prefix=$out|" $dev/lib/pkgconfig/*.pc
    fi
  '';

  postInstall = ''
    # Install the FIPS module
    $bin/bin/openssl fipsinstall -out $out/etc/ssl/fipsmodule.cnf -module $out/lib/ossl-modules/fips.so

    # Update openssl.cnf to include FIPS configuration
    sed -i \
      -e "s|^# \.include fipsmodule\.cnf|.include $out/etc/ssl/fipsmodule.cnf|" \
      -e 's/^# \(fips = fips_sect\)/\1/' \
      -e 's/^\(default = default_sect\)/# \1/' \
      $out/etc/ssl/openssl.cnf
  '';

  meta = with lib; {
    description = "FIPS-compliant OpenSSL ${version}";
    license = licenses.openssl;
    platforms = platforms.unix;
  };
}
