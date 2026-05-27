{
  config,
  lib,
  pkgs,
  ...
}:
{
  environment.systemPackages = with pkgs; [
    gdb
    neovim
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

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  system.stateVersion = "25.11";
}
