{ stdenv, fetchFromGitHub, cmake, bison, pkgconfig, libuecc, libsodium, libcap, json_c }:

stdenv.mkDerivation rec {
  version = "16";
  rev = "e31253760be07fe0c8d490b4a93017857e015b9a";
  name = "fastd-${version}-${rev}";

  src = fetchFromGitHub {
    owner = "fpletz";
    repo = "fastd";
    rev = "${rev}";
    sha256 = "150lnass743nlmc0q0swvs9qbzadxxxqmdv9h6zw72kd0g56cd04";
  };

  buildInputs = [ cmake bison pkgconfig libuecc libsodium libcap json_c ];

  enableParallelBuilding = true;
}
