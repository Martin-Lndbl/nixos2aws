{
  lib,
  pkgs,
  ...
}:
{
  boot.kernelPackages = pkgs.linuxPackages_7_0;

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

  services.envfs.enable = true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  system.stateVersion = "25.11";
}
