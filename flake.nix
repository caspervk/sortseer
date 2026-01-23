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
    forAllSystems = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed;
  in {
    formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra);

    packages = forAllSystems (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      default = pkgs.buildGoModule {
        pname = "sortseer";
        version = "0.0.1";

        src = ./.;

        vendorHash = "sha256-PbGOT36n1gyHr0OK0GqZL7B04WHJv+781nGJZIj9LgY=";
      };
    });

    # https://wiki.nixos.org/wiki/NixOS_modules
    nixosModules = {
      default = {
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
              ExecStart = "${self.packages.${pkgs.system}.default}/bin/sortseer";
              Restart = "always";
              DynamicUser = true;
              # Allow binding to privileged ports
              AmbientCapabilities = "CAP_NET_BIND_SERVICE";
            };
          };
        };
      };
    };
  };
}
