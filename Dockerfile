FROM ubuntu:20.04
RUN apt-get update && apt-get install -y \
    build-essential git meson pkg-config \
    libglib2.0-dev \
    libpixman-1-dev \
    libaio-dev \
    && rm -rf /var/lib/apt/lists/*
