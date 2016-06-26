{ stdenv, fetchgit, cmake }:

stdenv.mkDerivation rec {
  version = "7";
  name = "libuecc-${version}";

  src = fetchgit {
    url = "git://git.universe-factory.net/libuecc";
    rev = "refs/tags/v${version}";
    sha256 = "1sm05aql75sh13ykgsv3ns4x4zzw9lvzid6misd22gfgf6r9n5fs";
  };

  buildInputs = [ cmake ];

  enableParallelBuilding = true;
}
