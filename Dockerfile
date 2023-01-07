ARG ARCH=x86_64

FROM ubuntu:20.04
ARG DEBIAN_FRONTEND=noninteractive
ARG ARCH
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
RUN --mount=target=/sandbox,rw \
    ./build.sh $ARCH-softmmu /opt

FROM ubuntu:20.04
ARG ARCH
ARG QEMU=/opt/qemu-system-$ARCH
COPY --from=0 /opt /opt
RUN ldd $QEMU
RUN $QEMU --version
RUN echo "#!/bin/sh -x\nexec $QEMU \"\$@\"" | tee /usr/local/entrypoint.sh \
 && chmod +x /usr/local/entrypoint.sh
ENTRYPOINT ["/usr/local/entrypoint.sh"]
CMD ["-net", "nic,model=virtio", \
     "-net", "user,hostfwd=tcp::8022-:22", \
     "-drive", "file=/vm.img,if=none,format=qcow2,id=disk1", \
     "-device", "virtio-blk-pci,drive=disk1,bootindex=1", \
     "-serial", "mon:stdio"]
