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
      nixosConfigurations.x86_64-minimal = lib.nixosSystem {
        specialArgs = { inherit inputs; };
        modules = [
          ./configurations/x86_64-minimal.nix
        ];
      };

      nixosConfigurations.aarch64-minimal = lib.nixosSystem {
        specialArgs = { inherit inputs; };
        modules = [
          ./configurations/aarch64-minimal.nix
        ];
      };
      packages = forSystems (system: {
        default = self.packages.${system}.x86;
        x86 = mkAMI "x86_64-minimal";
        aarch = mkAMI "aarch64-minimal";
      });

      apps = forSystems (system: {
        default = self.apps.${system}.x86;
        x86 = mkVM "x86_64-minimal";
        aarch = mkVM "aarch64-minimal";
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
