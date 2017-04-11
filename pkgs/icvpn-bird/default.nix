{ stdenv, fetchFromGitHub, python3, python3Packages }:

let

  icvpn-scripts = fetchFromGitHub {
    owner = "freifunk";
    repo = "icvpn-scripts";
    rev = "dfc6cd7b9e464e6847d443b134c1e54ddfc7b8c6";
    sha256 = "1ac0khq2hfxb3rkmdvc0vcb3z9wpzw9yy1l6vsv80qjp13h2qppb";
  };

in

stdenv.mkDerivation rec {
  name = "icvpn-bird-${version}";
  version = "2017-04-11";

  src = fetchFromGitHub {
    owner = "freifunk";
    repo = "icvpn-meta";
    rev = "466056b34c6b7f69de7002e6e48d4f6eae001c3c";
    sha256 = "0zbwl155bvj797g0rgywqwqp13iym3bicm3n2qzn256ypny4qy30";
  };

  phases = [ "unpackPhase" "buildPhase" ];

  buildInputs = [ python3 python3Packages.pyyaml ];

  buildPhase = ''
    mkdir $out
    echo "Building IPv4 BGP peer configs"
    python3 ${icvpn-scripts}/mkbgp -4 -x muenchen -s $src -P 0 -d icpeers -p icvpn_ > $out/peers4
    echo "Building IPv6 BGP peer configs"
    python3 ${icvpn-scripts}/mkbgp -6 -x muenchen -s $src -P 0 -d icpeers -p icvpn_ > $out/peers6
    echo "Building IPv4 BGP ROA table"
    python3 ${icvpn-scripts}/mkroa -4 -x muenchen -s $src > $out/roa4
    echo "Building IPv6 BGP ROA table"
    python3 ${icvpn-scripts}/mkroa -6 -x muenchen -s $src > $out/roa6
    echo "Build unbound config"
    python3 ${icvpn-scripts}/mkdns -x muenchen -f unbound -s $src > $out/unbound.conf
  '';

}

