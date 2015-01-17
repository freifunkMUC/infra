{ stdenv, fetchgit, cmake, pkgconfig, libuecc }:

stdenv.mkDerivation rec {
  version = "0.3.2";
  name = "ecdsautils-${version}";

  src = fetchgit {
    url = "https://github.com/tcatm/ecdsautils.git";
    rev = "refs/tags/v${version}";
    sha256 = "0510v8r499hc7n8np5szfvqznam35x36xcqz1h1i7gd76d1lxld1";
  };

  buildInputs = [ cmake pkgconfig libuecc ];

  enableParallelBuilding = true;
}
