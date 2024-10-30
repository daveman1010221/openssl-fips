{ stdenv, fetchurl, lib, gnumake, gcc, perl, coreutils, patchelf }:

stdenv.mkDerivation rec {
  pname = "openssl-fips";
  version = "3.0.8"; # Use the FIPS-validated version

  src = fetchurl {
    url = "https://www.openssl.org/source/openssl-${version}.tar.gz";
    sha256 = "bBPSvzj98x6sPOKjRwc2c/XWMmM5jx9p0N9KQSU+Sz4=";
  };

  buildInputs = [ gnumake gcc perl patchelf ];

  configurePhase = ''
    patchShebangs .
    ./Configure enable-fips --prefix=$out --openssldir=$out/etc/ssl
  '';

  buildPhase = ''
    make -j$NIX_BUILD_CORES
  '';

  installPhase = ''
    make install
    install -Dm644 LICENSE.txt $out/share/licenses/${pname}/LICENSE.txt
  '';

  preFixup = ''
    # Patch binaries to have correct RPATH
    for bin in $out/bin/*; do
      patchelf --set-rpath $out/lib:$out/lib64 $bin || true
    done
  '';

  meta = with lib; {
    description = "FIPS-compliant OpenSSL ${version}";
    license = licenses.openssl;
    platforms = platforms.unix;
    homepage = "https://www.openssl.org";
    maintainers = with maintainers; [ your-name-here ];
  };

}