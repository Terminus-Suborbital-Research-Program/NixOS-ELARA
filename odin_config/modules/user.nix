{ config, pkgs, ... }:

{
  users.users.terminus = {
    isNormalUser = true;
    extraGroups = [ "wheel" "dialout" "gpio" "i2c" "uart" "video" ];
    hashedPassword =
      "$6$/y/JpKnBdDNKy4TT$AwhlCR6pIDBvvzdk8ZIKQFUQ/qp4o5lGJJq3kLQtnFHfuW6eJbbz7Pd/MxDOV8Ie0/0moYgCxTln0a9UA0Edz.";

    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL/QIvKf8yNyDwfBHuyoL9lrhnewB9FO+33SnxyoD+AJ lucas@nixos"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFXPxcaJrD7Lu2P1/CxCwoKySNrszKuXgJteVZFo9vk3 supergoodname77@cachyos-x8664"
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCX4xbbfhNuS6F5cb1dwHMmi+0T5B+Tea8QVfiYP5Ncia5J+BiMFxEH9S49QY9kpln3FchKxhWerUeftbW2gGUkdICIdjyEjShNYXHsSQoqvxlhaSvxJ5NsDpsu+kR1PoSrHmWyUcea5Bqy6S3lLEb5EcOzNjhuquJCoDRgRZQHNaPDHz3i+92bIAWAosu+mMkEa5/SxIxAh/6z+P3loHshtYWdEsMupOlX5MxHfXOepFVN7KTX36Rrqao198TSc0oik9JIOMUlmTc/EaU4PvXHI5I3T43JXOpFTLrJWkUGpPbUOaNzz7yOYqr2hvClA9aOzJIXtYWTcagQqFI2+VsstvNA1ci6/0UVhtBxuH1vs5F5P8IM6fScs9WCu4TE2rEDThzfrHpCuLWFhsYV+5dxGXEm+RrJmroUpelnm67CrNWgqgQPqJq55MZi0hHoxOXiFd/FyLwmULhajIfRJjkm2S1zbXAHUQ2Wju6mV2YrMpNlkpURKRcNtJx4OqLa1wE= bigmeech@hephaestus"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJZIG2yd5QRkMm1458RhZH9po2lDQy+PHB8JrnNIl0IH maachytka@gmail.com"
    ];
  };
}
