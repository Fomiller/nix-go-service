# GENERATED FILE — managed by the fomiller platform flake.
# Do not edit manually: changes will be overwritten by `nix run .#generate`.
# To customize, edit repo.nix in this repository instead.

FROM golang:1.23 AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -o /out/app ./...

FROM gcr.io/distroless/static-debian12
COPY --from=build /out/app /app
ENTRYPOINT ["/app"]

RUN echo 'sneaky manual patch'
