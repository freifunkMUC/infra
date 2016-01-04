{ stdenv, fetchgit, cmake, bison, pkgconfig, libuecc, libsodium, libcap, json_c }:

stdenv.mkDerivation rec {
  version = "17";
  name = "fastd-${version}";

  src = fetchgit {
    url = "git://git.universe-factory.net/fastd";
    rev = "refs/tags/v${version}";
    sha256 = "1xpazdpx0bzbkzqfvy5sbdg6hrk93179kvkgckg7z2cp1v9b21sy";
  };

  nativeBuildInputs = [ pkgconfig bison cmake ];
  buildInputs = [ libuecc libsodium libcap json_c ];

  enableParallelBuilding = true;
}
