{
  lib,
  fetchpatch,
  callPackage,
  ocaml-ng,
  ...
}@genericDefinition:

let
  upstreamPatches = import ../generic/patches.nix {
    inherit lib;
    inherit fetchpatch;
  };

  upstreamPatchList = lib.lists.flatten (
    with upstreamPatches;
    [
      QUBES_REPRODUCIBLE_BUILDS
    ]
  );
in

callPackage (import ../generic/default.nix {
  pname = "xen";
  branch = "4.17";
  version = "4.17.5";
  latest = false;
  pkg = {
    xen = {
      rev = "430ce6cd936546ad883ecd1c85ddea32d790604b";
      hash = "sha256-UoMdXRW0yWSaQPPV0rgoTZVO2ghdnqWruBHn7+ZjKzI=";
      patches = [ ] ++ upstreamPatchList;
    };
    qemu = {
      rev = "ffb451126550b22b43b62fb8731a0d78e3376c03";
      hash = "sha256-G0hMPid9d3fd1jAY7CiZ33xUZf1hdy96T1VUKFGeHSk=";
      patches = [ ];
    };
    seaBIOS = {
      rev = "d239552ce7220e448ae81f41515138f7b9e3c4db";
      hash = "sha256-UKMceJhIprN4/4Xe4EG2EvKlanxVcEi5Qcrrk3Ogiik=";
      patches = [ ];
    };
    ovmf = {
      rev = "7b4a99be8a39c12d3a7fc4b8db9f0eab4ac688d5";
      hash = "sha256-Qq2RgktCkJZBsq6Ch+6tyRHhme4lfcN7d2oQfxwhQt8=";
      patches = [ ];
    };
    miniOS = {
      rev = "5bcb28aaeba1c2506a82fab0cdad0201cd9b54b3";
      hash = "sha256-7t98LCISXUrGkn1+IvDom+E55fYJ6aQeE3mHuJ19OjU=";
      patches = [ ];
    };
    ipxe = {
      rev = "1d1cf74a5e58811822bee4b3da3cff7282fcdfca";
      hash = "sha256-8pwoPrmkpL6jIM+Y/C0xSvyrBM/Uv0D1GuBwNm+0DHU=";
      patches = [ ];
    };
    extFiles = {
      gmp = {
        version = "4.3.2";
        hash = "sha256-k2FiwDEohsIVgQAreZMoKaoEjPr5k3xiZa6qFPHNF3U=";
      };
      lwip = {
        version = "1.3.0";
        hash = "sha256-dy5NVQ4HgmZl7QUowHHdVATvfb4YJaOMitvCoAvKlI8=";
      };
      newlib = {
        version = "1.16.0";
        hash = "sha256-20JjlJZcSMHSkCPhzG2WXqa5qQNdioSb4nUMpGWaPQc=";
      };
      pciutils = {
        version = "2.2.9";
        hash = "sha256-9grmHPvV2h2EnQvqoh9ZPDjayTWfCz3cYS9EdAgmWyQ=";
      };
      polarssl = {
        version = "1.1.4";
        hash = "sha256-LSn9BKDQuina5r0p+0GJRMCNORZmXcynSvspfvN1hLY=";
      };
      tpm_emulator = {
        version = "0.7.4";
        hash = "sha256-TkjqDYPdlEHMGvBKsYzWyWG5+lTVy/LC/u4DiYjepFk=";
      };
      zlib = {
        version = "1.2.3";
        hash = "sha256-F5XH0GekMXQRP98DRHUy83PhxsV8CNYdnk6b5eJEsF4=";
      };
    };
  };
}) ({ ocamlPackages = ocaml-ng.ocamlPackages_4_14; } // genericDefinition)
