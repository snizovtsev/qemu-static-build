#!/bin/bash

set -e
set -o pipefail

info() {
    >&2 echo "=== " $@  " === "
}

preamble() {
    info "Write preamble"
    IFS='' apt list ${BUILD_DEPS} 2> /dev/null \
      | tail -n +2 | sed 's/.*/dpkg: \0/'
    echo -n "git: libslirp "
    git -C ../qemu describe --long
    git -C ../libslirp describe --long
}

prepare() {
    info "Prepare build directory"
    MARKER=build/auto-created-by-build-sh

    if test -e build
    then
        if test -f $MARKER
        then
            rm -rf build
        else
            echo "ERROR: ./build dir already exists and was not previously created by this script"
            exit 1
        fi
    fi

    mkdir -p build/install
    mkdir -p build/dist/qemu-bundle
    touch $MARKER
    cd build || exit 1
}

patch1="../patches/qemu-semistatic-build.patch"

patch() {
    info "Apply patches"
    ln -sf ../../libslirp ../qemu/subprojects
    git -C ../qemu apply "${patch1}"
    trap unpatch EXIT
}

unpatch() {
    info "Reverting patches"
    rm -f ../qemu/subprojects/libslirp
    git -C ../qemu apply -R "${patch1}"
}

configure() {
    info "Configure"
    ../qemu/configure \
        --prefix=/ \
        --datadir="" \
        --with-suffix="" \
        --firmwarepath="" \
        --target-list=x86_64-softmmu \
        --enable-fdt=internal \
        --without-default-features \
        --static=semi \
        --enable-strip \
        --enable-avx2 \
        --enable-kvm \
        --enable-pie \
        --enable-linux-aio \
        --enable-slirp
    # lipstick: Remove extra "/./" from firmware search path
    sed -i 's/DIR "\/\.\//DIR "/' config-host.h
}

build() {
    info "Build"
    DESTDIR=./install ninja install
}

distribute() {
    info "Distribute"
    strings install/bin/qemu* > qemu.strings
    mv install/bin/qemu* dist/
    mv install/keymaps dist/qemu-bundle

    # Find which blobs are referred in binary and move to bundle
    find install -maxdepth 1 -type f -printf '%P\n' | while read -r blob; do
        if ! grep -q "$blob" qemu.strings; then
        echo -n "-$blob "
        continue
        fi
        echo -n "+$blob "
        mv install/"$blob" dist/qemu-bundle/
    done
    echo
    rm qemu.strings
}

prepare
preamble > build-manifest.txt
patch
configure | tee -a build-manifest.txt
build
distribute | tee -a build-manifest.txt
