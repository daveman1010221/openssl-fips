{ stdenv, fetchurl }:

stdenv.mkDerivation rec {
  pname = "openssl-fips";
  version = "3.0.9";

  src = fetchurl {
    url = "https://www.openssl.org/source/openssl-${version}.tar.gz";
    sha256 = "<fips-source-sha256>";
  };

  configurePhase = ''
    ./Configure enable-fips --prefix=$out
  '';

  buildPhase = ''
    make
  '';

  installPhase = ''
    make install_sw install_fips
    $out/bin/openssl fipsinstall -out $out/etc/fipsmodule.cnf -module $out/lib/ossl-modules/fips.so
  '';

  meta = with stdenv.lib; {
    description = "FIPS-compliant OpenSSL ${version}";
    license = licenses.openssl;
    platforms = platforms.linux;
  };
}