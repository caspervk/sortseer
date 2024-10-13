{
  description = "sortseer";

  inputs = {
    nixpkgs = {
      url = "github:NixOS/nixpkgs/nixos-unstable";
    };
  };

  outputs = {
    self,
    nixpkgs,
  }: let
    # https://github.com/ryantm/agenix/blob/main/flake.nix
    eachSystem = nixpkgs.lib.genAttrs [
      "aarch64-linux"
      "x86_64-linux"
    ];
  in {
    formatter = eachSystem (system: nixpkgs.legacyPackages.${system}.alejandra);

    packages = eachSystem (system: {
      sortseer = nixpkgs.legacyPackages.${system}.buildGoModule {
        pname = "sortseer";
        version = "0.0.1";

        src = ./.;

        vendorHash = "sha256-PbGOT36n1gyHr0OK0GqZL7B04WHJv+781nGJZIj9LgY=";
      };

      default = self.packages.${system}.sortseer;
    });

    # https://wiki.nixos.org/wiki/NixOS_modules
    nixosModules = {
      sortseer = {
        config,
        lib,
        pkgs,
        ...
      }: let
        cfg = config.services.sortseer;
      in {
        options.services.sortseer = {
          enable = lib.mkEnableOption "sortseer service";
        };

        config = lib.mkIf cfg.enable {
          systemd.services.sortseer = {
            after = ["network.target"];
            wantedBy = ["multi-user.target"];
            serviceConfig = {
              ExecStart = "${self.packages.${pkgs.system}.sortseer}/bin/sortseer";
              Restart = "always";
              DynamicUser = true;
              # Allow binding to privileged ports
              AmbientCapabilities = "CAP_NET_BIND_SERVICE";
            };
          };
        };
      };

      default = self.nixosModules.sortseer;
    };
  };
}
