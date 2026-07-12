{
  name = "go-service";
  language = "go";

  ci = {
    security = true;
    release = true;
  };

  kubernetes = {
    helm = true;
    argocd = true;
  };

  codeowners = [ "@Fomiller" ];
}
