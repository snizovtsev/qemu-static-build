FROM ubuntu:20.04

ARG DEBIAN_FRONTEND=noninteractive
ENV BUILD_DEPS      \
    gcc             \
    libglib2.0-dev  \
    libpixman-1-dev \
    libaio-dev

RUN apt-get update && apt-get install -y \
    build-essential git meson pkg-config \
    $BUILD_DEPS \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /sandbox
ADD "https://www.random.org/cgi-bin/randbyte?nbytes=10&format=h" /skipcache
RUN --mount=target=/sandbox,rw ./build.sh
