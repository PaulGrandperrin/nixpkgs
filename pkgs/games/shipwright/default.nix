{ stdenv
, lib
, fetchFromGitHub
, makeDesktopItem
, copyDesktopItems
, makeWrapper
, python3
, llvmPackages
, libX11
, libXrandr
, glew
, SDL2
, libpulseaudio
, libpng
, bzip2
, StormLib

, romVariant ? "debug"
, requireFile
, ootRom ? requireFile {
    name = "oot-${romVariant}.z64";
    message = ''
      This nix expression requires that oot-${romVariant}.z64 is already part of the store.
      To get this file you can dump your Ocarina of Time's cartridge to a file,
      and add it to the nix store with nix-store --add-fixed sha256 <FILE>.
      Note that if you are not using the debug version of the rom you will need to overwrite
      the romVariant attribute with "pal-gc", the only other supported variant as of writing this.
    '';
    sha256 = {
      debug = "94bdeb4ab906db112078a902f4477e9712c4fe803c4efb98c7b97c3f950305ab";
      pal-gc = "f788793d27aac3f8d91be5f242c4134217c615bfddd5c70384521ea2153435d2";
    }.${romVariant};
  }
}:

stdenv.mkDerivation rec {
  pname = "shipwright";
  version = "unstable-2022-05-15";

  src = fetchFromGitHub {
    owner = "harbourmasters";
    repo = "shipwright";
    rev = "076887e71f52d4258aa8fc77d3efeafe09d234d8";
    sha256 = "17pj1v3id8dl9q26ik8bz75dnij2bqvf33c2jx3yl3l7lx3aj8ic";
  };

  enableParallelBuilding = true;

  # Copied from the building guide
  makeFlags = [
    "DEBUG=0"
    "OPTFLAGS=-O2"
  ];

  # Linking fails without this
  hardeningDisable = [ "all" ];

  # Many warnings are being treated as errors
  NIX_CFLAGS_COMPILE = [
    "-Wno-error"
  ];

  nativeBuildInputs = [
    python3
    llvmPackages.bintools
    copyDesktopItems
    makeWrapper
  ];

  buildInputs = [
    libX11
    libXrandr
    glew
    SDL2
    libpulseaudio
    libpng
    bzip2
    StormLib
  ];

  postPatch = ''
    # This script attempts to call git to retrieve the commit hash,
    # so we have to manually patch it in instead.
    substituteInPlace ZAPDTR/ZAPD/genbuildinfo.py \
      --replace "label = subprocess" "#label = subprocess" \
      --replace "+ label +" "+ \"${builtins.substring 0 7 src.rev}\" +"
  '';

  preBuild = ''
    # Used for asset extraction
    ln -s ${ootRom} OTRExporter/oot.z64

    # Extract assets and compile some stuff, this is needed for the build phase
    cd "soh"
    make setup ''${makeFlags[@]} -j$NIX_BUILD_CORES
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/{bin,lib,share/pixmaps}
    cp soh.elf oot.otr $out/lib
    cp ../OTRExporter/assets/ship_of_harkinian/icons/gSohIcon.png $out/share/pixmaps/soh.png

    # oot.otr needs to be in the same directory as soh itself
    makeWrapper $out/lib/soh.elf $out/bin/soh \
      --argv0 "$out/lib"

    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "soh";
      icon = "soh";
      exec = "soh";
      genericName = "Ship of Harkinian";
      desktopName = "soh";
      categories = [ "Game" ];
    })
  ];

  meta = with lib; {
    homepage = "https://github.com/HarbourMasters/Shipwright";
    description = "A PC port of Ocarina of Time with modern controls, widescreen, high-resolution, and more";
    longDescription = ''
      An PC port of Ocarina of Time with modern controls, widescreen, high-resolution and more, based off of decompilation.
      Note that you must supply an OoT rom yourself to use this package because propietary assets are extracted from it.
      Currently only the "debug" and "pal-gc" variants of the rom are supported upstream.
      You can change the target variant like this: shipwright.override { romVariant = "pal-gc"; }
    '';
    mainProgram = "soh";
    platforms = [ "i686-linux" ];
    maintainers = [ maintainers.ivar ];
    license = with licenses; [
      # OTRExporter, OTRGui, ZAPDTR, libultraship
      mit
      # Ship of Harkinian itself
      unfree
    ];
  };
}
