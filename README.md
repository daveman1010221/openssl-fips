# FIPS-compliant OpenSSL Flake

This flake provides a FIPS-compliant build of OpenSSL version 3.0.8 for NixOS and macOS.

## Description

This flake builds OpenSSL with FIPS compliance enabled, suitable for environments where FIPS compliance is required.

The OpenSSL FIPS Object Module is a general-purpose cryptographic module delivered as open source code. It is FIPS 140-2 validated and provides a set of cryptographic algorithms and services for use by applications that require cryptographic security.

## Supported Systems

- x86_64-linux
- x86_64-darwin

# FIPS-compliant OpenSSL Flake Examples

This document provides examples of how to use the FIPS-compliant OpenSSL flake in different contexts. The examples are simplified for easier understanding.

## Example 1: Including OpenSSL FIPS in a Nix Shell

You can create a development shell that includes the FIPS-compliant OpenSSL.

```
{
  description = "Development shell with FIPS-compliant OpenSSL";

  inputs.openssl-fips.url = "github:MaxfieldKassel/nix-flake-openssl-fips";

  outputs = { self, openssl-fips, ... }:
    let
      system = "x86_64-linux"; # replace with your system
      pkgs = import openssl-fips.inputs.nixpkgs { inherit system; };
    in
    {
      devShell.${system} = pkgs.mkShell {
        buildInputs = [ openssl-fips.packages.${system}.default ];
        shellHook = ''
          export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${openssl-fips.packages.${system}.default}/lib
        '';
      };
    };
}
```

To enter the development shell, use the following command:

Ensure that you are in the directory containing the flake.nix file before running the following command.
```bash
nix develop
```

## Example 2: Building a Docker Image with Nix and OpenSSL FIPS

Here's how to build a Docker image that includes the FIPS-compliant OpenSSL.

```
{
  description = "Docker image with FIPS-compliant OpenSSL";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    openssl-fips.url = "github:MaxfieldKassel/nix-flake-openssl-fips";
  };

  outputs = { self, nixpkgs, openssl-fips, ... }:
    let
      system = "x86_64-linux"; # Select the target system
      pkgs = import nixpkgs { inherit system; };
    in
    {
      packages.${system} = {
        dockerImage = pkgs.dockerTools.buildImage {
          name = "openssl-fips-image";
          tag = "latest";
          copyToRoot = pkgs.buildEnv {
            name = "docker-env";
            paths = with pkgs; [
              bashInteractive # For shell access
              uutils-coreutils-noprefix # Basic utilities
              openssl-fips.packages.${system}.default
              # Add other packages if needed
            ];
            pathsToLink = [ "/bin" "/lib" "/share" ]; # Specify paths to include
          };
          config = {
            Cmd = [ "/bin/bash" ];
            Env = [ "LD_LIBRARY_PATH=/lib" ]; # Ensure OpenSSL finds its libraries
          };
        };
      };
    };
}
```

To build and run the Docker image, use the following commands:

Ensure that you are in the directory containing the flake.nix file before running the following commands.
```bash
nix build .#dockerImage
docker load < result
docker run -it openssl-fips-image
```

## Example 3: Using OpenSSL FIPS in a NixOS Configuration

You can include the FIPS-compliant OpenSSL in a NixOS system configuration.

```
{ config, pkgs, ... }:

{
  nixpkgs.overlays = [
    (final: prev: {
      openssl-fips = (import (builtins.fetchGit {
        url = "https://github.com/YourUsername/openssl-fips-flake";
      })).packages.${builtins.currentSystem}.default;
    })
  ];

  environment.systemPackages = with pkgs; [
    openssl-fips
    # Other packages
  ];
}
```


## License

This project is licensed under the OpenSSL License. See the [LICENSE](https://openssl-library.org/source/license/index.html) on the OpenSSL website for more information.
```