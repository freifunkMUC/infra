{ stdenv, fetchgit, cmake }:

stdenv.mkDerivation rec {
  version = "6";
  name = "libuecc-${version}";

  src = fetchgit {
    url = "git://git.universe-factory.net/libuecc";
    rev = "refs/tags/v${version}";
    sha256 = "1rrgq6ld8v0n51637g9ggf7sfgzzjpbr1i3xc3pb69wyaws6gg7x";
  };

  buildInputs = [ cmake ];

  enableParallelBuilding = true;
}
