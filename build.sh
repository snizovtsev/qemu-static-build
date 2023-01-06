#!/bin/bash

set -e
set -o pipefail

info() {
    >&2 echo "=== " $@  " === "
}

cleanbuild() {
    info "Clean build directory"
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
}

patch1="../patches/qemu-semistatic-build.patch"

gitlike_apply() {
    local opts="${@:1:$#-1}"
    local file="${@: -1}"
    patch $opts -f --dry-run < "$file" \
    && patch $opts -f < "$file" >/dev/null \
    || echo "Failed to apply $file"
}

prepare() {
    info "Prepare sources"
    gitlike_apply -d ../qemu "${patch1}"
    ln -sf ../../libslirp ../qemu/subprojects
    trap unpatch EXIT
}

unpatch() {
    info "Reverting patches"
    rm -f ../qemu/subprojects/libslirp
    gitlike_apply -Rd ../qemu "${patch1}"
}

configure() {
    info "Configure"
    IFS='' apt list ${BUILD_DEPS} 2> /dev/null \
      | tail -n +2 | sed 's/.*/dpkg: \0/'
    ../qemu/configure \
        --target-list=x86_64-softmmu \
        --prefix=/ \
        --datadir="" \
        --with-suffix="" \
        --firmwarepath="" \
        --with-git-submodules=ignore \
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

cleanbuild
cd build || exit 1
prepare
configure | tee -a build-manifest.txt
build
distribute | tee -a build-manifest.txt
