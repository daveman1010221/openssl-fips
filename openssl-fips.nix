{ stdenv, fetchurl, lib, gnumake, gcc, perl, coreutils }:

stdenv.mkDerivation rec {
  pname = "openssl-fips";
  version = "3.0.8"; 

  src = fetchurl {
    url = "https://www.openssl.org/source/openssl-${version}.tar.gz";
    sha256 = "bBPSvzj98x6sPOKjRwc2c/XWMmM5jx9p0N9KQSU+Sz4=";
  };

  buildInputs = [ gnumake gcc perl ];
  #phases = ["configurePhase" "buildPhase" "fixupPhase" "postInstall"];

  configurePhase =  ''
    patchShebangs .
    ./Configure enable-fips --prefix=$out --openssldir=$out/etc/ssl
  '';

  buildPhase =  ''
    make -j$NIX_BUILD_CORES
  '';

  installPhase = ''
    make install -j$NIX_BUILD_CORES
  '';

  fixupPhase = ''
  echo "Appending custom commands to fixupPhase"
  export LD_LIBRARY_PATH=$out/lib64:$out/lib
  $out/bin/openssl fipsinstall -out $out/etc/ssl/fipsmodule.cnf -module $out/lib64/ossl-modules/fips.so
'';


  
  meta = with lib; {
    description = "FIPS-compliant OpenSSL ${version}";
    license = licenses.openssl;
    platforms = platforms.unix;
  };
}