{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    inputs@{
      self,
      nixpkgs,
      ...
    }:
    let
      inherit (nixpkgs) lib;
      forSystems = lib.genAttrs lib.systems.flakeExposed;

      mkVM = name: {
        type = "app";
        program = lib.getExe self.nixosConfigurations.${name}.config.system.build.vm;
      };

      mkAMI = name: self.nixosConfigurations.${name}.config.system.build.images.amazon;
    in
    {
      nixosConfigurations.minimal = lib.nixosSystem {
        specialArgs = { inherit inputs; };
        modules = [
          # "${nixpkgs}/nixos/modules/virtualisation/amazon-image.nix"
          ./configurations/minimal.nix
        ];
      };

      packages = forSystems (system: {
        default = self.packages.${system}.minimal;
        minimal = mkAMI "minimal";
      });

      apps = forSystems (system: {
        default = self.apps.${system}.minimal;
        minimal = mkVM "minimal";
        # An image with hardware configuration relevant to irene 
        irene = mkVM "irene";
      });

      devShell = forSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        pkgs.mkShellNoCC {
          buildInputs = with pkgs; [
            qemu_kvm
            gdb
            awscli2
            just
          ];

        }
      );

    };
}
