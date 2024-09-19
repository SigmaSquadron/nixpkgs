#!/usr/bin/env nix-shell
#!nix-shell -i bash -p gitMinimal curl gnupg nix-prefetch-git nixfmt-rfc-style
# shellcheck disable=SC2206,SC2207 shell=bash
set -o errexit
set -o pipefail
set -o nounset

#TODO: Use `jq` instead of `sed`.
#TODO: Accept the small security drawback and make this script runnable by r-ryantm.

# This script expects to be called in an interactive terminal somewhere inside Nixpkgs.
echo "Preparing..."
nixpkgs=$(git rev-parse --show-toplevel)
xenPath="$nixpkgs/pkgs/applications/virtualization/xen"
rm -rf /tmp/xenUpdateScript
mkdir /tmp/xenUpdateScript

# Import and verify PGP key.
curl --silent --output /tmp/xenUpdateScript/xen.asc https://keys.openpgp.org/vks/v1/by-fingerprint/23E3222C145F4475FA8060A783FE14C957E82BD9
gpg --homedir /tmp/xenUpdateScript/.gnupg --quiet --import /tmp/xenUpdateScript/xen.asc
fingerprint="$(gpg --homedir /tmp/xenUpdateScript/.gnupg --with-colons --fingerprint "pgp@xen.org" 2>/dev/null | awk -F: '/^pub:.*/ { getline; print $10}')"
echo -e "Please ascertain through multiple external sources that the \e[1;32mXen Project PGP Key Fingerprint\e[0m is indeed \e[1;33m$fingerprint\e[0m. If that is not the case, \e[1;31mexit immediately\e[0m."
read -r -p $'Press \e[1;34menter\e[0m to continue with a pre-filled expected fingerprint, or input an arbitrary PGP fingerprint to match with the key\'s fingerprint: ' userInputFingerprint
userInputFingerprint=${userInputFingerprint:-"23E3222C145F4475FA8060A783FE14C957E82BD9"}

# Clone xen.git.
echo -e "Cloning \e[1;34mxen.git\e[0m..."
git clone --quiet https://xenbits.xenproject.org/git-http/xen.git /tmp/xenUpdateScript/xen
cd /tmp/xenUpdateScript/xen

# Get list of versions and branches.
versionList="$(git tag --list "RELEASE-*" | sed s/RELEASE-//g | sed s/4.1.6.1//g | sort --numeric-sort)"
latestVersion=$(echo "$versionList" | tr ' ' '\n' | tail --lines=1)
branchList=($(echo "$versionList" | tr ' ' '\n' | sed s/\.[0-9]*$//g | awk '!seen[$0]++'))

# Figure out which versions we're actually going to install.
minSupportedBranch="$(grep "  minSupportedVersion = " "$xenPath"/generic/default.nix | sed s/'  minSupportedVersion = "'//g | sed s/'";'//g)"
supportedBranches=($(for version in "${branchList[@]}"; do if [ "$(printf '%s\n' "$minSupportedBranch" "$version" | sort -V | head -n1)" = "$minSupportedBranch" ]; then echo "$version"; fi; done))
supportedVersions=($(for version in "${supportedBranches[@]}"; do echo "$versionList" | tr ' ' '\n' | grep "$version" | tail --lines=1; done))

echo -e "\e[1mNOTE\e[0m: As we're also pre-fetching the submodules, QEMU and OVMF may take a very long time to fetch."

# Main loop that installs every supportedVersion.
for version in "${supportedVersions[@]}"; do
    echo -e "\n------------------------------------------------"
    branch=${version/%.[0-9]/}
    if [[ "$version" == "$latestVersion" ]]; then
        latest=true
        echo -e "\nFound \e[1;34mlatest\e[0m release: \e[1;32mXen $version\e[0m in branch \e[1;36m$branch\e[0m."
    else
        latest=false
        echo -e "\nFound \e[1;33msecurity-supported\e[0m release: \e[1;32mXen $version\e[0m in branch \e[1;36m$branch\e[0m."
    fi

    # Verify PGP key automatically. If the fingerprint matches what the user specified, or the default fingerprint, then we consider it trusted.
    cd /tmp/xenUpdateScript/xen
    if [[ "$fingerprint" = "$userInputFingerprint" ]]; then
        echo "$fingerprint:6:" | gpg --homedir /tmp/xenUpdateScript/.gnupg --quiet --import-ownertrust
        (git verify-tag RELEASE-"$version" 2>/dev/null && echo -e "\n\e[1;32mSuccessfully authenticated Xen $version.\e[0m") || (echo -e "\e[1;31merror:\e[0m Unable to verify tag \e[1;32mRELEASE-$version\e[0m.\n- It is possible that \e[1;33mthis script has broken\e[0m, the Xen Project has \e[1;33mcycled their PGP keys\e[0m, or a \e[1;31msupply chain attack is in progress\e[0m.\n\n\e[1;31mPlease update manually.\e[0m" && exit 1)
    else
        echo -e "\e[1;31merror:\e[0m Unable to verify \e[1;34mpgp@xen.org\e[0m's fingerprint.\n- It is possible that \e[1;33mthis script has broken\e[0m, the Xen Project has \e[1;33mcycled their PGP keys\e[0m, or an \e[1;31mimpersonation attack is in progress\e[0m.\n\n\e[1;31mPlease update manually.\e[0m" && exit 1
    fi

    git switch --quiet --detach RELEASE-"$version"

    # Originally we told people to go check the Makefile themselves.
    echo -e -n "\nDetermining source versions from Xen Makefiles..."
    qemuVersion="$(grep "QEMU_UPSTREAM_REVISION ?=" /tmp/xenUpdateScript/xen/Config.mk | sed s/"QEMU_UPSTREAM_REVISION ?= "//g)"
    seaBIOSVersion="$(grep "SEABIOS_UPSTREAM_REVISION ?= rel-" /tmp/xenUpdateScript/xen/Config.mk | sed s/"SEABIOS_UPSTREAM_REVISION ?= "//g)"
    ovmfVersion="$(grep "OVMF_UPSTREAM_REVISION ?=" /tmp/xenUpdateScript/xen/Config.mk | sed s/"OVMF_UPSTREAM_REVISION ?= "//g)"
    miniOSVersion="$(grep "MINIOS_UPSTREAM_REVISION ?=" /tmp/xenUpdateScript/xen/Config.mk | sed s/"MINIOS_UPSTREAM_REVISION ?= "//g)"
    ipxeVersion="$(grep "IPXE_GIT_TAG :=" /tmp/xenUpdateScript/xen/tools/firmware/etherboot/Makefile | sed s/"IPXE_GIT_TAG := "//g)"
    echo "done!"

    # Find the versions for the extFiles.
    echo -e -n "Determining extFiles from stubdom ./configure script..."
    gmpVersion="$(grep 'GMP_VERSION="' /tmp/xenUpdateScript/xen/stubdom/configure | sed 's/GMP_VERSION="//g;s/"//g')"
    lwipVersion="$(grep 'LWIP_VERSION="' /tmp/xenUpdateScript/xen/stubdom/configure | sed 's/LWIP_VERSION="//g;s/"//g')"
    newlibVersion="$(grep 'NEWLIB_VERSION="' /tmp/xenUpdateScript/xen/stubdom/configure | sed 's/NEWLIB_VERSION="//g;s/"//g')"
    pciutilsVersion="$(grep 'LIBPCI_VERSION="' /tmp/xenUpdateScript/xen/stubdom/configure | sed 's/LIBPCI_VERSION="//g;s/"//g')"
    polarsslVersion="$(grep 'POLARSSL_VERSION="' /tmp/xenUpdateScript/xen/stubdom/configure | sed 's/POLARSSL_VERSION="//g;s/"//g')"
    tpm_emulatorVersion="$(grep 'TPMEMU_VERSION="' /tmp/xenUpdateScript/xen/stubdom/configure | sed 's/TPMEMU_VERSION="//g;s/"//g')"
    zlibVersion="$(grep 'ZLIB_VERSION="' /tmp/xenUpdateScript/xen/stubdom/configure | sed 's/ZLIB_VERSION="//g;s/"//g')"
    echo -e "done!\n"

    # Use `nix-prefetch-git` to fetch `rev`s and `hash`es.
    echo "Pre-fetching sources and determining hashes..."
    echo -e -n "  \e[1;32mXen\e[0m..."
    fetchXen=$(nix-prefetch-git --url https://xenbits.xenproject.org/git-http/xen.git --rev RELEASE-"$version" --quiet)
    finalVersion="$(echo "$fetchXen" | tr ', ' '\n ' | grep -ie rev | sed s/'  "rev": "'//g | sed s/'"'//g)"
    hash="$(echo "$fetchXen" | tr ', ' '\n ' | grep -ie hash | sed s/'  "hash": "'//g | sed s/'"'//g)"
    echo "done!"
    echo -e -n "  \e[1;36mQEMU\e[0m..."
    fetchQEMU=$(nix-prefetch-git --url https://xenbits.xenproject.org/git-http/qemu-xen.git --rev "$qemuVersion" --quiet --fetch-submodules)
    finalQEMUVersion="$(echo "$fetchQEMU" | tr ', ' '\n ' | grep -ie rev | sed s/'  "rev": "'//g | sed s/'"'//g)"
    qemuHash="$(echo "$fetchQEMU" | tr ', ' '\n ' | grep -ie hash | sed s/'  "hash": "'//g | sed s/'"'//g)"
    echo "done!"
    echo -e -n "  \e[1;36mSeaBIOS\e[0m..."
    fetchSeaBIOS=$(nix-prefetch-git --url https://xenbits.xenproject.org/git-http/seabios.git --rev "$seaBIOSVersion" --quiet)
    finalSeaBIOSVersion="$(echo "$fetchSeaBIOS" | tr ', ' '\n ' | grep -ie rev | sed s/'  "rev": "'//g | sed s/'"'//g)"
    seaBIOSHash="$(echo "$fetchSeaBIOS" | tr ', ' '\n ' | grep -ie hash | sed s/'  "hash": "'//g | sed s/'"'//g)"
    echo "done!"
    echo -e -n "  \e[1;36mOVMF\e[0m..."
    ovmfHash="$(nix-prefetch-git --url https://xenbits.xenproject.org/git-http/ovmf.git --rev "$ovmfVersion" --quiet --fetch-submodules | grep -ie hash | sed s/'  "hash": "'//g | sed s/'",'//g)"
    echo "done!"
    echo -e -n "  \e[1;36mMiniOS\e[0m..."
    fetchMiniOS=$(nix-prefetch-git --url https://xenbits.xenproject.org/git-http/mini-os.git --rev "$miniOSVersion" --quiet --fetch-submodules)
    finalMiniOSVersion="$(echo "$fetchMiniOS" | tr ', ' '\n ' | grep -ie rev | sed s/'  "rev": "'//g | sed s/'"'//g)"
    miniOSHash="$(echo "$fetchMiniOS" | tr ', ' '\n ' | grep -ie hash | sed s/'  "hash": "'//g | sed s/'"'//g)"
    echo "done!"
    echo -e -n "  \e[1;36miPXE\e[0m..."
    ipxeHash="$(nix-prefetch-git --url https://github.com/ipxe/ipxe.git --rev "$ipxeVersion" --quiet | grep -ie hash | sed s/'  "hash": "'//g | sed s/'",'//g)"
    echo "done!"

    # Find the hashes of the extFiles through `nix store prefetch-file`.
    echo -e "Pre-fetching extFiles and determining hashes..."
    echo -e -n "  \e[1;36mgmp\e[0m..."
    gmpHash="$(nix store prefetch-file https://xenbits.xenproject.org/xen-extfiles/gmp-$gmpVersion.tar.bz2 --json 2> /dev/null | sed 's/{"hash":"//g' | sed s/'","storePath":".*'//g)"
    echo "done!"
    echo -e -n "  \e[1;36mlwip\e[0m..."
    lwipHash="$(nix store prefetch-file https://xenbits.xenproject.org/xen-extfiles/lwip-$lwipVersion.tar.gz --json 2> /dev/null | sed 's/{"hash":"//g' | sed s/'","storePath":".*'//g)"
    echo "done!"
    echo -e -n "  \e[1;36mnewlib\e[0m..."
    newlibHash="$(nix store prefetch-file https://xenbits.xenproject.org/xen-extfiles/newlib-$newlibVersion.tar.gz --json 2> /dev/null | sed 's/{"hash":"//g' | sed s/'","storePath":".*'//g)"
    echo "done!"
    echo -e -n "  \e[1;36mpciutils\e[0m..."
    pciutilsHash="$(nix store prefetch-file https://xenbits.xenproject.org/xen-extfiles/pciutils-$pciutilsVersion.tar.bz2 --json 2> /dev/null | sed 's/{"hash":"//g' | sed s/'","storePath":".*'//g)"
    echo "done!"
    echo -e -n "  \e[1;36mpolarssl\e[0m..."
    polarsslHash="$(nix store prefetch-file https://xenbits.xenproject.org/xen-extfiles/polarssl-$polarsslVersion-gpl.tgz --json 2> /dev/null | sed 's/{"hash":"//g' | sed s/'","storePath":".*'//g)"
    echo "done!"
    echo -e -n "  \e[1;36mtpm_emulator\e[0m..."
    tpm_emulatorHash="$(nix store prefetch-file https://xenbits.xenproject.org/xen-extfiles/tpm_emulator-$tpm_emulatorVersion.tar.gz --json 2> /dev/null | sed 's/{"hash":"//g' | sed s/'","storePath":".*'//g)"
    echo "done!"
    echo -e -n "  \e[1;36mzlib\e[0m..."
    zlibHash="$(nix store prefetch-file https://xenbits.xenproject.org/xen-extfiles/zlib-$zlibVersion.tar.gz --json 2> /dev/null | sed 's/{"hash":"//g' | sed s/'","storePath":".*'//g)"
    echo "done!"

    cd "$xenPath"

    echo -e "\nFound the following revisions:\
    \n  \e[1;32mXen\e[0m:     \e[1;33m$finalVersion\e[0m (\e[1;33m$hash\e[0m)\
    \n  \e[1;36mQEMU\e[0m:    \e[1;33m$finalQEMUVersion\e[0m (\e[1;33m$qemuHash\e[0m)\
    \n  \e[1;36mSeaBIOS\e[0m: \e[1;33m$finalSeaBIOSVersion\e[0m (\e[1;33m$seaBIOSHash\e[0m)\
    \n  \e[1;36mOVMF\e[0m:    \e[1;33m$ovmfVersion\e[0m (\e[1;33m$ovmfHash\e[0m)\
    \n  \e[1;36mMiniOS\e[0m:  \e[1;33m$finalMiniOSVersion\e[0m (\e[1;33m$miniOSHash\e[0m)\
    \n  \e[1;36miPXE\e[0m:    \e[1;33m$ipxeVersion\e[0m (\e[1;33m$ipxeHash\e[0m)\
    \n\
    \n  \e[1;32mextFiles\e[0m:\
    \n  \e[1;36mgmp\e[0m:          \e[1;33m$gmpVersion\e[0m  (\e[1;33m$gmpHash\e[0m)\
    \n  \e[1;36mlwip\e[0m:         \e[1;33m$lwipVersion\e[0m  (\e[1;33m$lwipHash\e[0m)\
    \n  \e[1;36mnewlib\e[0m:       \e[1;33m$newlibVersion\e[0m (\e[1;33m$newlibHash\e[0m)\
    \n  \e[1;36mpciutils\e[0m:     \e[1;33m$pciutilsVersion\e[0m  (\e[1;33m$pciutilsHash\e[0m)\
    \n  \e[1;36mpolarssl\e[0m:     \e[1;33m$polarsslVersion\e[0m  (\e[1;33m$polarsslHash\e[0m)\
    \n  \e[1;36mtpm_emulator\e[0m: \e[1;33m$tpm_emulatorVersion\e[0m  (\e[1;33m$tpm_emulatorHash\e[0m)\
    \n  \e[1;36mzlib\e[0m:         \e[1;33m$zlibVersion\e[0m  (\e[1;33m$zlibHash\e[0m)"

    # Set OCaml Version
    read -r -p $'\nEnter the corresponding \e[1;33mOCaml\e[0m version for \e[1;32mXen '"$version"$'\e[0m, or press \e[1;34menter\e[0m for the default value of \e[1;32m4_14\e[0m: ' ocamlVersion
    ocamlVersion=${ocamlVersion:-"4_14"}

    mkdir -p "$branch"/
    rm -f "$branch"/default.nix

    # Prepare any .patch files that are called by Nix through a path value.
    echo -e "\nPlease add any required patches to version \e[1;32m$branch\e[0m in \e[1;34m$branch/\e[0m, and press \e[1;34menter\e[0m when done."
    read -r -p $'Remember to follow the naming specification as defined in \e[1;34m./README.md\e[0m.'

    echo -e "\nDiscovering patches..."
    discoveredXenPatches="$(find "$branch"/ -type f -name "[0-9][0-9][0-9][0-9]-xen-*-$branch.patch" -printf "./%f ")"
    discoveredQEMUPatches="$(find "$branch"/ -type f -name "[0-9][0-9][0-9][0-9]-qemu-*-$branch.patch" -printf "./%f ")"
    discoveredSeaBIOSPatches="$(find "$branch"/ -type f -name "[0-9][0-9][0-9][0-9]-seabios-*-$branch.patch" -printf "./%f ")"
    discoveredOVMFPatches="$(find "$branch"/ -type f -name "[0-9][0-9][0-9][0-9]-ovmf-*-$branch.patch" -printf "./%f ")"
    discoveredMiniOSPatches="$(find "$branch"/ -type f -name "[0-9][0-9][0-9][0-9]-minios-*-$branch.patch" -printf "./%f ")"
    discoveredIPXEPatches="$(find "$branch"/ -type f -name "[0-9][0-9][0-9][0-9]-ipxe-*-$branch.patch" -printf "./%f ")"

    discoveredXenPatchesEcho=${discoveredXenPatches:-"\e[1;31mNone found!\e[0m"}
    discoveredQEMUPatchesEcho=${discoveredQEMUPatches:-"\e[1;31mNone found!\e[0m"}
    discoveredSeaBIOSPatchesEcho=${discoveredSeaBIOSPatches:-"\e[1;31mNone found!\e[0m"}
    discoveredOVMFPatchesEcho=${discoveredOVMFPatches:-"\e[1;31mNone found!\e[0m"}
    discoveredMiniOSPatchesEcho=${discoveredMiniOSPatches:-"\e[1;31mNone found!\e[0m"}
    discoveredIPXEPatchesEcho=${discoveredIPXEPatches:-"\e[1;31mNone found!\e[0m"}

    echo -e "Found the following patches:\
    \n  \e[1;32mXen\e[0m:     \e[1;33m$discoveredXenPatchesEcho\e[0m\
    \n  \e[1;36mQEMU\e[0m:    \e[1;33m$discoveredQEMUPatchesEcho\e[0m\
    \n  \e[1;36mSeaBIOS\e[0m: \e[1;33m$discoveredSeaBIOSPatchesEcho\e[0m\
    \n  \e[1;36mOVMF\e[0m:    \e[1;33m$discoveredOVMFPatchesEcho\e[0m\
    \n  \e[1;36mMiniOS\e[0m:  \e[1;33m$discoveredMiniOSPatchesEcho\e[0m\
    \n  \e[1;36miPXE\e[0m:    \e[1;33m$discoveredIPXEPatchesEcho\e[0m"

    # Prepare patches that are called in ./patches.nix.
    defaultPatchListInit=("QUBES_REPRODUCIBLE_BUILDS" "XSA_460" "XSA_461" )
    read -r -a defaultPatchList -p $'\nWould you like to override the \e[1;34mupstreamPatches\e[0m list for \e[1;32mXen '"$version"$'\e[0m? If no, press \e[1;34menter\e[0m to use the default patch list: [ \e[1;34m'"${defaultPatchListInit[*]}"$' \e[0m]: '
    defaultPatchList=(${defaultPatchList[@]:-${defaultPatchListInit[@]}})
    upstreamPatches=${defaultPatchList[*]}

    # Write and format default.nix file.
    echo -e -n "\nWriting updated \e[1;34mversionDefinition\e[0m..."
    cat >"$branch"/default.nix <<EOF
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

  upstreamPatchList = lib.lists.flatten (with upstreamPatches; [
    $upstreamPatches
  ]);
in

callPackage (import ../generic/default.nix {
  pname = "xen";
  branch = "$branch";
  version = "$version";
  latest = $latest;
  pkg = {
    xen = {
      rev = "$finalVersion";
      hash = "$hash";
      patches = [ $discoveredXenPatches ] ++ upstreamPatchList;
    };
    qemu = {
      rev = "$finalQEMUVersion";
      hash = "$qemuHash";
      patches = [ $discoveredQEMUPatches ];
    };
    seaBIOS = {
      rev = "$finalSeaBIOSVersion";
      hash = "$seaBIOSHash";
      patches = [ $discoveredSeaBIOSPatches ];
    };
    ovmf = {
      rev = "$ovmfVersion";
      hash = "$ovmfHash";
      patches = [ $discoveredOVMFPatches ];
    };
    miniOS = {
      rev = "$finalMiniOSVersion";
      hash = "$miniOSHash";
      patches = [ $discoveredMiniOSPatches ];
    };
    ipxe = {
      rev = "$ipxeVersion";
      hash = "$ipxeHash";
      patches = [ $discoveredIPXEPatches ];
    };
    extFiles = {
      gmp = {
        version = "$gmpVersion";
        hash = "$gmpHash";
      };
      lwip = {
        version = "$lwipVersion";
        hash = "$lwipHash";
      };
      newlib = {
        version = "$newlibVersion";
        hash = "$newlibHash";
      };
      pciutils = {
        version = "$pciutilsVersion";
        hash = "$pciutilsHash";
      };
      polarssl = {
        version = "$polarsslVersion";
        hash = "$polarsslHash";
      };
      tpm_emulator = {
        version = "$tpm_emulatorVersion";
        hash = "$tpm_emulatorHash";
      };
      zlib = {
        version = "$zlibVersion";
        hash = "$zlibHash";
      };
    };
  };
}) ({ ocamlPackages = ocaml-ng.ocamlPackages_$ocamlVersion; } // genericDefinition)
EOF
echo done!

    echo -n "Formatting..."
    nixfmt "$branch"/default.nix
    echo done!

    echo -e "\n\e[1;32mSuccessfully produced $branch/default.nix.\e[0m"
done

echo -e -n "\nCleaning up..."
rm -rf /tmp/xenUpdateScript
echo done!
