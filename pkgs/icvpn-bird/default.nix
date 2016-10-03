{ stdenv, fetchFromGitHub, python3, python3Packages }:

let

  icvpn-scripts = fetchFromGitHub {
    owner = "freifunk";
    repo = "icvpn-scripts";
    rev = "6c92328c19a61355ac9e73dcc6dcb5f7fe364b92";
    sha256 = "10b0jyrqkwqn7wsfhhmpi08cr5341pvgiz7bsdrjy75kqq8kysy4";
  };

in

stdenv.mkDerivation rec {
  name = "icvpn-bird-${version}";
  version = "2016-09-16";

  src = fetchFromGitHub {
    owner = "freifunk";
    repo = "icvpn-meta";
    rev = "2de8afe33c87ec4294f777bf5a3a24590c072902";
    sha256 = "0a7kqq7r4d8mpikyh42qcc7xnncvlczzhg7y0cdyq6bqf4frsbr4";
  };

  phases = [ "unpackPhase" "buildPhase" ];

  buildInputs = [ python3 python3Packages.pyyaml ];

  buildPhase = ''
    mkdir $out
    echo "Building IPv4 BGP peer configs"
    python3 ${icvpn-scripts}/mkbgp -4 -s $src -P 0 -d icpeers -p icvpn_ > $out/peers4
    echo "Building IPv6 BGP peer configs"
    python3 ${icvpn-scripts}/mkbgp -6 -s $src -P 0 -d icpeers -p icvpn_ > $out/peers6
    echo "Building IPv4 BGP ROA table"
    python3 ${icvpn-scripts}/mkroa -4 -s $src > $out/roa4
    echo "Building IPv6 BGP ROA table"
    python3 ${icvpn-scripts}/mkroa -6 -s $src > $out/roa6
  '';

}

