# qemu-static-build
Dockerfile for building static version of qemu

## 2 in 1: Clone and build using Docker

``` sh
DOCKER_BUILDKIT=1 docker build -t qemu-static \
  https://github.com/snizovtsev/qemu-static-build.git#v1.0 
```

## Clone and build locally

``` sh
git clone --recurse-submodules \
  https://github.com/snizovtsev/qemu-static-build.git
cd qemu-static-build
DOCKER_BUILDKIT=1 docker build . -t qemu-static
# or podman build . -t qemu-static
```

## Run QEMU from image

``` sh
docker run --rm -it qemu-static --version
docker run --rm -it -v $PWD/ubuntu.qcow2:/vm.img qemu-static
```

## Extract build artifacts from image

``` sh
docker create --name qemu-static qemu-static
docker cp qemu-static:/opt/ qemu-dist
docker rm qemu-static
```
