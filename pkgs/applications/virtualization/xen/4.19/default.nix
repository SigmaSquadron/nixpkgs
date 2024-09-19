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
      XSA_460
      XSA_461
    ]
  );
in

callPackage (import ../generic/default.nix {
  pname = "xen";
  branch = "4.19";
  version = "4.19.0";
  latest = true;
  pkg = {
    xen = {
      rev = "026c9fa29716b0ff0f8b7c687908e71ba29cf239";
      hash = "sha256-Q6x+2fZ4ITBz6sKICI0NHGx773Rc919cl+wzI89UY+Q=";
      patches = [ ] ++ upstreamPatchList;
    };
    qemu = {
      rev = "0df9387c8983e1b1e72d8c574356f572342c03e6";
      hash = "sha256-BX+LXfNzwdUMALwwI1ZDW12dJ357oynjnrboLHREDGQ=";
      patches = [ ];
    };
    seaBIOS = {
      rev = "a6ed6b701f0a57db0569ab98b0661c12a6ec3ff8";
      hash = "sha256-hWemj83cxdY8p+Jhkh5GcPvI0Sy5aKYZJCsKDjHTUUk=";
      patches = [ ];
    };
    ovmf = {
      rev = "ba91d0292e593df8528b66f99c1b0b14fadc8e16";
      hash = "sha256-htOvV43Hw5K05g0SF3po69HncLyma3BtgpqYSdzRG4s=";
      patches = [ ];
    };
    miniOS = {
      rev = "8b038c7411ae7e823eaf6d15d5efbe037a07197a";
      hash = "sha256-WDoQKgNOFEmv5DJ/y5FKc5wJraea07qWsqkWD/f+6vU=";
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
