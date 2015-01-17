{ stdenv, fetchgit, cmake, bison, pkgconfig, libuecc, libsodium, libcap, json_c }:

stdenv.mkDerivation rec {
  version = "16";
  name = "fastd-${version}";

  src = fetchgit {
    url = "git://git.universe-factory.net/fastd";
    rev = "refs/tags/v${version}";
    sha256 = "10c2k4zfxlwd075f7nii7832gp57cgxwnh5ip50nacghqjwcsndc";
  };

  buildInputs = [ cmake bison pkgconfig libuecc libsodium libcap json_c ];

  enableParallelBuilding = true;
}
