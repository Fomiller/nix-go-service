# GENERATED FILE — managed by the fomiller platform flake.
# Do not edit manually: changes will be overwritten by `nix run .#generate`.
# To customize, edit repo.nix in this repository instead.


build:
    go build ./...

test:
    go test ./... -race -cover

lint:
    go vet ./...

ci: lint test build

