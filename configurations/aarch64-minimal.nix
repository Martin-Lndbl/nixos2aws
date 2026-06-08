{
  lib,
  pkgs,
  ...
}:
{
  boot.kernelPackages = pkgs.linuxPackages_7_0;
  boot.loader.grub.enable = false;
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  nixpkgs.hostPlatform = "aarch64-linux";

  environment.systemPackages = with pkgs; [
    gdb
    vim
    gitMinimal
    pciutils
  ];

  virtualisation.vmVariant = {
    virtualisation = {
      memorySize = 1024;
      cores = 4;
      graphics = false;
    };
  };

  services.openssh.enable = true;
  networking.hostName = "aws";

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  networking.modemmanager.enable = false;

  services.envfs.enable = true;

  system.stateVersion = "25.11";
}
