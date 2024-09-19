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
  branch = "4.18";
  version = "4.18.3";
  latest = false;
  pkg = {
    xen = {
      rev = "bd51e573a730efc569646379cd59ccba967cde97";
      hash = "sha256-OFiFdpPCXR+sWjzFHCORtY4DkWyggvxkcsGdgEyO1ts=";
      patches = [ ] ++ upstreamPatchList;
    };
    qemu = {
      rev = "0df9387c8983e1b1e72d8c574356f572342c03e6";
      hash = "sha256-BX+LXfNzwdUMALwwI1ZDW12dJ357oynjnrboLHREDGQ=";
      patches = [ ];
    };
    seaBIOS = {
      rev = "ea1b7a0733906b8425d948ae94fba63c32b1d425";
      hash = "sha256-J2FuT+FXn9YoFLSfxDOxyKZvKrys59a6bP1eYvEXVNU=";
      patches = [ ];
    };
    ovmf = {
      rev = "ba91d0292e593df8528b66f99c1b0b14fadc8e16";
      hash = "sha256-htOvV43Hw5K05g0SF3po69HncLyma3BtgpqYSdzRG4s=";
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
