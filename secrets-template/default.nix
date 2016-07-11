{
  stats = {
    servername = {
      host = "stats.ffmuc.net";
      port = 2342;
    };
  };

  fastd = {
    gw01 = {
      secret = "481eb3a58d1838db8969213320c791185e9ccf0b71a7086e411183e94097bf41";
      public = "24d48fcc553522e711d6edb7e2be696f269f12a54759e9e44f2ef2dea2556127";
    };
    gw02 = {
      secret = "883021f207abb6950320b8f26f381ce7b78e0527e58a69815d3417b4f855047c";
      public = "3d93f2ccc4fe5374de3c2d771a59b13b43866fee34fa3affa13cfb61f1e8f0f5";
    };
    gw03 = {
      secret = "28fe295d4082ff5fc96bace4e27e200350860f3af3f13b4ae54cac2c5213c25c";
      public = "f45fde68e1ecb08f209765d318a3c49d161a351df91fc91bab2b9e65c2fddd33";
    };
  };

  openvpn = {
    vpnprovidername = {
      config = ''
        ...
      '';
      up = "ip route replace default via 10.4.0.1 dev $1 metric 42 table 42";
    };
  };

  rootPassword = "password";
}
