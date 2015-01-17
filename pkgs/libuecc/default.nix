{ stdenv, fetchgit, cmake }:

stdenv.mkDerivation rec {
  version = "4";
  name = "libuecc-${version}";

  src = fetchgit {
    url = "git://git.universe-factory.net/libuecc";
    rev = "refs/tags/v${version}";
    sha256 = "0pmij96p038vdd86zk1z5rdrsiam2n57qpl1v69pn0yxiibh11pn";
  };

  buildInputs = [ cmake ];

  enableParallelBuilding = true;
}
