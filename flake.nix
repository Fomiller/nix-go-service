{
  description = "go-service — consumer of the fomiller platform flake";

  inputs = {
    # Standard nixpkgs pin — provides `pkgs` (build tools, pkgs.lib, etc).
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # flake-utils.eachDefaultSystem below is what makes `nix run .#generate`
    # work on whatever machine you're on (aarch64-darwin, x86_64-linux, ...)
    # without this flake having to enumerate systems itself.
    flake-utils.url = "github:numtide/flake-utils";

    # This is the pin: it's the ONE line Renovate would touch when the
    # platform ships a new version (bump `?ref=vX.Y.Z`), and it's the only
    # thing standing between "this repo" and "whatever the platform team
    # currently considers standard."
    platform = {
      url = "github:Fomiller/nix-platform-flake?ref=v0.4.0&dir=raw-nix";
      # Without this, `platform` would drag in its own copy of nixpkgs
      # (a second full nixpkgs eval + a second store of derivations to
      # build). `follows` tells Nix "use *this* flake's nixpkgs input
      # instead" — one nixpkgs, shared, faster evals, smaller lock file.
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, platform }:
    # eachDefaultSystem runs the function below once per system in
    # flake-utils' default list and merges the results into
    # `apps.<system>.generate` etc. It's what lets `nix run .#generate`
    # resolve without you ever typing a system string.
    flake-utils.lib.eachDefaultSystem (system:
      let
        # Build pkgs for whichever system nix run/build resolved to.
        pkgs = import nixpkgs { inherit system; };

        # The one file you're actually meant to edit in this repo — see
        # repo.nix. Everything else here is plumbing to wire it up.
        repoConfig = import ./repo.nix;

        # This is the actual generator call: platform's mkRepository, given
        # this system's pkgs and this repo's declared config, returns
        # { files, filesDrv, generateApp }.
        repo = platform.lib.mkRepository pkgs repoConfig;

        # --- Nix-native container build, kept alongside the platform's
        # generated Dockerfile rather than replacing it — folding this into
        # mkRepository would mean the generator needs a real vendorHash/
        # cargoHash per repo, which (unlike a Dockerfile) can't be derived
        # from repo.nix alone. Two derivations instead of one Dockerfile
        # RUN-step build:

        # 1. The Go binary itself, built by Nix instead of `docker build`
        #    running `go build` in a golang:1.23 container. `vendorHash =
        #    null` is valid because main.go has zero external dependencies
        #    (stdlib only) — nothing to vendor. A real service with
        #    third-party imports would need a real vendorHash here (Nix
        #    fixes it to make the build hermetic; `nix build` tells you the
        #    right value the first time if you get it wrong).
        goServiceBin = pkgs.buildGoModule {
          pname = "go-service";
          version = "0.1.0";
          src = ./.;
          vendorHash = null;
        };
      in
      {
        # `nix run .#generate` and bare `nix run` both resolve to the same
        # script: copy platform.filesDrv's contents into the working tree.
        apps.generate = repo.generateApp;
        apps.default = repo.generateApp;

        packages.go-service = goServiceBin;

        # 2. The OCI image. No Dockerfile, no base image, no `apt-get`, no
        # shell in the final image at all — dockerTools.buildLayeredImage
        # copies exactly goServiceBin's closure (the binary + its runtime
        # deps, here just glibc) into content-addressed layers. Two builds
        # from an unchanged binary produce byte-identical layers, so a
        # registry push after a docs-only change re-uses every layer.
        packages.container = pkgs.dockerTools.buildLayeredImage {
          name = "go-service";
          tag = "latest";
          contents = [ goServiceBin ];
          config = {
            Cmd = [ "${goServiceBin}/bin/go-service" ];
            ExposedPorts = { "8080/tcp" = { }; };
          };
        };
      }
    );
}
