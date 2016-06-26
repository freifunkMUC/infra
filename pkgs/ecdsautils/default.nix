{ stdenv, fetchFromGitHub, cmake, pkgconfig, libuecc }:

stdenv.mkDerivation rec {
  version = "0.3.2";
  name = "ecdsautils-${version}";

  src = fetchFromGitHub {
    owner = "tcatm";
    repo = "ecdsautils";
    rev = "v${version}";
    sha256 = "03p8pb9fd020fcqwxw4zhvfjv6cczw8hxqa4m9ldjh1iwqfhgrlj";
  };

  buildInputs = [ cmake pkgconfig libuecc ];

  enableParallelBuilding = true;
}
