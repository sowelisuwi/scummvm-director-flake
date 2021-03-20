{
  description = "Environment and packages for ScummVM Director engine development";

  inputs = {
    drxtract = {
      url = "github:System25/drxtract";
      flake = false;
    };

    nixpkgs = {
      url = "github:NixOS/nixpkgs/nixos-unstable";
      flake = true;
    };

    projectorrays = {
      url = "github:ProjectorRays/ProjectorRays";
      flake = false;
    };

    scummvm = {
      url = "github:scummvm/scummvm/master";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, ... } @ inputs:
    let
      # Using a system not listed here? Let me know!
      supportedSystems = [
        "x86_64-linux"
        "x86_64-darwin"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems f;
    in
    {
      packages = forAllSystems (system:
        with import nixpkgs { inherit system; };

        {
          basiliskii = stdenv.mkDerivation rec {
            pname = "basiliskii";
            version = src.rev;

            src = fetchFromGitHub {
              owner = "cebix";
              repo = "macemu";
              rev = "d684527b27ecca9b76a7895abd25b1eba5317a1c";
              hash = "sha256-WbE/DLDmL3gImOGqb9HbjQXvAHUHAUan4HCCrThKLYI=";
            };

            nativeBuildInputs = [
              autoconf
              automake
              pkg-config
            ];

            buildInputs = [ gtk2 SDL2 vde2 ];

            patches = [ ./basiliskii-format-security.diff ];

            configureFlags = [
              "--enable-sdl-video"
              "--enable-sdl-audio"
              "--enable-jit-compiler"
              "--with-bincue"
              "--with-gtk"
              "--with-sdl2"
              "--with-vdeplug"
            ];

            postPatch = "patchShebangs .";

            preConfigure = "cd BasiliskII/src/Unix";

            configureScript = "./autogen.sh";

            installFlags = [ "PREFIX=$(out)" ];

            meta = with lib; {
              description = "68k Macintosh emulator";
              license = licenses.gpl2;
              maintainers = [ maintainers.yegortimoshenko ];
              platforms = platforms.unix;
            };
          };

          d4player = stdenv.mkDerivation rec {
            pname = "d4player";
            version = src.rev;

            src = fetchFromGitHub {
              owner = "renaldobf";
              repo = "D4Player";
              rev = "c7e1b476fc912af59cb768bab2488d79bc7e9488";
              hash = "sha256-dE19ocKfBxDxez2LqRiala7jssz3T5wEqMaKzSa2YwU=";
            };

            buildInputs = [ allegro libpng ];

            postPatch = "patchShebangs .";

            installPhase = ''
              install -Dt $out/bin d4player
            '';

            meta = with lib; {
              description = "Player for Macromedia Director 4 movie files";
              license = licenses.unfree; # https://github.com/renaldobf/D4Player/issues/2
              maintainers = [ maintainers.yegortimoshenko ];
              platforms = platforms.unix;
            };
          };

          director-files-extract = stdenv.mkDerivation rec {
            pname = "director-files-extract";
            version = src.rev;

            src = fetchFromGitHub {
              owner = "maichiu";
              repo = "director-files-extract";
              rev = "6abbf96e784b8485f9e2237d4da3e5bb6ed926fe";
              hash = "sha256-kiCB1O70tSCGU+n/lyCIf5w1HI3EkMpnVC8C+LDtclg=";
            };

            buildInputs = [ python3 ];

            postPatch = ''
              patchShebangs .
            '';

            installPhase = ''
              mkdir --parents $out/bin
              install shock.py $out/bin/director-files-extract
              install fix_director_files.py $out/bin/fix-director-files
            '';

            meta = with lib; {
              description = "Extract Director movies and casts from Windows and Mac executables";
              license = licenses.unfree; # https://github.com/maichiu/director-files-extract/issues/4
              maintainers = [ maintainers.yegortimoshenko ];
              platforms = platforms.unix;
            };
          };

          drxtract = stdenv.mkDerivation {
            pname = "drxtract";
            version = inputs.drxtract.rev;

            src = inputs.drxtract;

            buildInputs = [ python3 ];

            postPatch = ''
              patchShebangs .
            '';

            installPhase = ''
              mkdir --parents $out/bin
              mv * $out/bin
            '';

            meta = with lib; {
              description = "Director 5 DRI and DRX files data extractor";
              license = licenses.gpl2;
              maintainers = [ maintainers.yegortimoshenko ];
              platforms = platforms.unix;
            };
          };

          projectorrays = stdenv.mkDerivation {
            pname = "projectorrays";
            version = inputs.projectorrays.rev;

            src = inputs.projectorrays;

            buildInputs = [ boost17x zlib ];

            installPhase = ''
              install -Dt $out/bin projectorrays
            '';

            meta = with lib; {
              description = "Lingo decompiler for Director";
              license = with licenses; [ asl20 mit ];
              maintainers = [ maintainers.yegortimoshenko ];
              platforms = platforms.unix;
            };
          };

          scummvm = scummvm.overrideAttrs (super: {
            pname = "scummvm-director";
            version = inputs.scummvm.rev;

            src = inputs.scummvm;

            configureFlags = super.configureFlags ++ [
              "--disable-all-engines"
              "--enable-engine=director"
            ];
          });
        }
      );

      devShell = forAllSystems (system:
        with import nixpkgs { inherit system; };
        with self.packages.${system};

        mkShell {
          buildInputs = [
            scummvm # ScummVM (Director engine only)
            basiliskii # 68k Macintosh emulator
            drxtract # Director 4/5 data extractor
            gdb # Debugger
            projectorrays # Lingo decompiler
          ];

          inputsFrom = [ scummvm ];
        }
      );
    };
}
