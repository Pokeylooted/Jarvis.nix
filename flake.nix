{
  description = "A structured and configureable NixOS system!";

  inputs = {
    master.url = "github:NixOS/nixpkgs";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/master"};
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware.url = "github:NixOS/nixos-hardware";
    utils.url = "github:numtide/flake-utils";

    emacs-overlay.url = "github:nix-community/emacs-overlay";
    neovim-nightly.url = "github:nix-community/neovim-nightly-overlay";
    rust-overlay.url = "github:oxalica/rust-overlay";

    nixos-cn = {
      url = "github:nixos-cn/flakes";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    mozilla-overlay = {
      url = "github:mozilla/nixpkgs-mozilla";
      flake = false;
    };

    # agenix.url = "github:ryantm/agenix";
    # naersk.url = "github:nmattia/naersk";

  };

  outputs = 
  { self
  , home-manager
  , nixpkgs
  , rust-overlay
  , neovim-nightly 
  , mozilla-overlay
  , nixos-cn
  , ...
  } inputs@:

  let 
    system = "x86_64-linux";

    overlays = with inputs; [ 
      rust-overlay
      emacs-overlay
      neovim-nightly 
      mozilla-overlay
    ];

    lib = nixpkgs.lib.extend
      (final: prev: (import ./lib final) // home-manager.lib);

    inherit (nixpkgs.lib) nixosSystem;
    inherit (home-manager.lib) homeManagerConfiguration;
    inherit (flake-utils.lib) eachDefaultSystem eachSystem;
    inherit (builtins) listToAttrs map;

    # Generate default NixOS config
    mkNixosConfig =
      { system ? "x86_64-linux"
      , hardwareModules
      , baseModules ? [
          home-manager.nixosModules.home-manager
          ./modules/nixos
        ]
      , extraModules ? [ ]
      }:

      nixosSystem {
        inherit system;
        modules = baseModules ++ hardwareModules ++ extraModules
          ++ [{ nixpkgs.overlays = overlays; }];
        specialArgs = { inherit inputs lib; };
      };

      # Generate default Home-Manager conf
      mkHomeConfig =
        { username
        , system ? "x86_64-linux"
        , baseModules ? [ ./modules/home-manager ]
        , extraModules ? [ ]
        }:

        homeManagerConfiguration rec {
          inherit system username;
          homeDirectory = "/home/${username}";
          extraSpecialArgs = { inherit inputs lib; };
          configuration = {
            imports = baseModules ++ extraModules
              ++ [{ nixpkgs.overlays = overlays; }];
          };
        };

  in {
    # Linux-related checks
    checks = listToAttrs (
      (map
        (system: {
          name = system;
          value = {
            nixos = self.nixosConfigurations.phil.config.system.build.toplevel;
            server = self.homeConfigurations.server.activationPackage;
          };
        })
      lib.platforms.linux)
    );

    nixosConfigurations = {
      thinkpad = mkNixosConfig {
        hardwareModules = [
          ./modules/hardware/thinkpad.nix
          # nixos-hardware.nixosModules.lenovo-thinkpad-e595
        ];
        extraModules = [ ./profiles/ThinkPad-E595.nix ];
      };
      
      probook = mkNixosConfig {
        hardwareModules = [
          ./modules/hardware/ProBook-440G3.nix
          # nixos-hardware.nixosModules.hp-probook-440g3
        ];
        extraModules = [ ./profiles/ProBook-440G3.nix ];
      };

    };

    homeConfigurations = {
      thinkpad = mkHomeConfig {
        username = "sirius";
        extraModules = [ ./profiles/home-manager/ThinkPad-E595.nix ];
      };

      probook = mkHomeConfig {
        username = "orca";
        extraModules = [ ./profiles/home-manager/ProBook-440G3.nix ];
      };

    };
  }
