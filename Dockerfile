# syntax=docker/dockerfile:1

ARG GO_VERSION=1.22.1
FROM --platform=$BUILDPLATFORM golang:${GO_VERSION} AS build
WORKDIR /src

RUN --mount=type=cache,target=/go/pkg/mod/ \
    --mount=type=bind,source=go.sum,target=go.sum \
    --mount=type=bind,source=go.mod,target=go.mod \
    go mod download -x

# Build stage
RUN --mount=type=cache,target=/go/pkg/mod/ \
    --mount=type=bind,target=. \
    CGO_ENABLED=0 go build -o /bin/ytarchive .

# Download latest ffmpeg static build
FROM ubuntu AS downloader

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive \
    apt-get install --no-install-recommends --assume-yes \
    wget ca-certificates xz-utils

RUN wget -O ffmpeg-git-amd64-static.tar.xz https://johnvansickle.com/ffmpeg/builds/ffmpeg-git-amd64-static.tar.xz
RUN tar -xf "ffmpeg-git-amd64-static.tar.xz" 
RUN mv ffmpeg-git-*-amd64-static/ffmpeg /usr/local/bin/
RUN rm -rf ffmpeg-git-*-amd64-static.tar.xz ffmpeg-git-*-amd64-static

# Runner, using ffmpeg from johnvansickle.com
FROM alpine:latest AS static

# Copy the executable from the "build" stage.
COPY --from=build /bin/ytarchive /usr/local/bin
COPY --from=downloader /usr/local/bin/ffmpeg /usr/local/bin

# What the container should run when it is started.
ENTRYPOINT [ "ytarchive" ]

# Runner, using ffmpeg from linuxserver
FROM linuxserver/ffmpeg:latest AS linuxserver

# Copy the executable from the "build" stage.
COPY --from=build /bin/ytarchive /usr/local/bin

# What the container should run when it is started.
ENTRYPOINT [ "ytarchive" ]
