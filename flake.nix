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
  };
}
