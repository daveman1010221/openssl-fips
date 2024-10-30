{ stdenv, fetchurl, lib, gnumake, gcc, perl, coreutils }:

stdenv.mkDerivation rec {
  pname = "openssl-fips";
  version = "3.0.9";

  src = fetchurl {
    url = "https://www.openssl.org/source/openssl-${version}.tar.gz";
    sha256 = "6xqwR4FHQ2D3fDGKuJ2MWgOrw45j1lpgPKu/GwCh3JA=";
  };

  # Add required build inputs
  buildInputs = [ gnumake gcc perl ];

  configurePhase = ''
    patchShebangs .
    ./Configure enable-fips --prefix=$out --openssldir=$out/etc/ssl
  '';

  buildPhase = ''
    make -j16
  '';

  installPhase = ''
    make install_sw install_fips
  '';

  postInstall = ''
    export LD_LIBRARY_PATH=$out/lib64:$out/lib
    $out/bin/openssl fipsinstall -out $out/etc/ssl/fipsmodule.cnf -module $out/lib64/ossl-modules/fips.so
  '';

  meta = with lib; {
    description = "FIPS-compliant OpenSSL ${version}";
    license = licenses.openssl;
    platforms = platforms.linux;
  };
}