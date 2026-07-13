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
    #
    # In production this would be `github:fomiller/platform?ref=v0.2.0`.
    # For this local POC (no GitHub push yet) we point at the sibling repo
    # via git+file, which behaves identically for locking/pinning purposes:
    # flake.lock records the exact commit, and `nix flake update platform`
    # is how a Renovate-driven bump would land here.
    platform = {
      url = "git+file:///Users/forrest/dev/personal/nix-platform-poc/platform?ref=v0.2.0";
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
      in
      {
        # `nix run .#generate` and bare `nix run` both resolve to the same
        # script: copy platform.filesDrv's contents into the working tree.
        apps.generate = repo.generateApp;
        apps.default = repo.generateApp;
      }
    );
}
