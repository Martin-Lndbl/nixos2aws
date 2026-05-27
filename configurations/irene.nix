{
  config,
  lib,
  pkgs,
  ...
}:
{
  boot.kernelModules = [ "kvm-amd" ];
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  virtualisation.vmVariant = {
    virtualisation = {
      memorySize = 1024;
      cores = 4;
      graphics = false;
      qemu.options = [
        "-device"
        "vfio-pci,host=c1:01.0,id=netvf0"
      ];
    };
  };

  boot.initrd.availableKernelModules = [ "iavf" ];

  environment.systemPackages = with pkgs; [
    gdb
    perf
    gcc
    neovim
    pciutils
  ];

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  system.stateVersion = "25.11";
}
