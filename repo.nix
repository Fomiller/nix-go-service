{
  name = "go-service";
  language = "go";

  ci = {
    security = true;
    release = true;
    # Demonstrates the ci.extraSteps escape hatch (FOM-51: "Customization
    # should happen through the repository definition ... rather than
    # modifying generated output directly") — each string is spliced into
    # build-test's step list as-is, so it must already be valid,
    # correctly-indented YAML at column 0.
    extraSteps = {
      pre = [
        "- name: print environment\n  run: env | sort"
      ];
      post = [
        "- name: print go version\n  run: go version"
      ];
    };
  };

  # Demonstrates the overrides.language escape hatch: pins this repo to a
  # specific Go build image variant without waiting on a platform release
  # that changes the "go" archetype's default for every consumer.
  overrides.language.buildImage = "golang:1.23-bookworm";

  kubernetes = {
    helm = true;
    argocd = true;
  };

  codeowners = [ "@Fomiller" ];
}
