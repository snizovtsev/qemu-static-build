#!/bin/bash

set -e
set -o pipefail

arch="$1"
outdir=$(readlink -f "$2")

info() {
    >&2 echo "=== " "$@"  " === "
}

cleanbuild() {
    info "Clean build directory"
    local marker=build/auto-created-by-build-sh

    if test -e build
    then
        if test -f $marker
        then
            rm -rf build
        else
            echo "ERROR: ./build dir already exists and was not previously created by this script"
            exit 1
        fi
    fi

    mkdir -p build/install
    mkdir -p "${outdir}"/qemu-bundle/keymaps
    touch $marker
}

patch1="../patches/qemu-semistatic-build.patch"

gitlike_apply() {
    local opts=( "${@:1:$#-1}" )
    local file=${*: -1}
    patch "${opts[@]}" -f --dry-run < "$file" \
    && patch "${opts[@]}" -f < "$file" >/dev/null \
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
    apt list ${BUILD_DEPS} \
      | tail -n +2 | sed 's/.*/dpkg: \0/'
    ../qemu/configure \
        --target-list="${arch}" \
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

    local executable=( install/bin/qemu-system-* )
    strings "${executable[0]}" > qemu.strings
    install -m755 "${executable[0]}" "${outdir}"/
    install -m644 install/keymaps/* "${outdir}"/qemu-bundle/keymaps/

    # Find which blobs are referred in binary and move to bundle
    find install -maxdepth 1 -type f -printf '%P\n' | while read -r blob; do
        if ! grep -q "$blob" qemu.strings; then
        echo -n "-$blob "
        continue
        fi
        echo -n "+$blob "
        install -m644 install/"$blob" "${outdir}"/qemu-bundle/
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
