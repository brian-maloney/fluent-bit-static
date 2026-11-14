# Debian ships no static libsystemd (https://bugs.debian.org/915566), so build
# one from Debian's own source package. This must stay on a systemd older than
# 256: later versions dlopen() the compression libraries, which cannot work in
# a static binary.
FROM debian:bookworm AS libsystemd

ENV DEBIAN_FRONTEND=noninteractive
RUN sed -i 's/^Types: deb$/Types: deb deb-src/' /etc/apt/sources.list.d/debian.sources && \
    apt update && \
    apt install -y build-essential dpkg-dev pkg-config meson ninja-build gperf python3-jinja2 \
        libcap-dev libmount-dev liblz4-dev liblzma-dev libzstd-dev

RUN mkdir /tmp/build /opt/libsystemd && chown nobody:nogroup /tmp/build /opt/libsystemd

USER nobody
WORKDIR /tmp/build

# Only the library is built. lz4/xz/zstd are needed to read compressed journal
# fields; everything else optional is switched off to keep the link simple.
RUN apt-get source systemd && \
    cd systemd-*/ && \
    meson setup build -Dmode=release -Dstatic-libsystemd=pic \
        -Dlz4=true -Dxz=true -Dzstd=true \
        -Dgcrypt=false -Dopenssl=false -Dselinux=false -Dtests=false && \
    ninja -C build version.h libsystemd.a && \
    mkdir -p /opt/libsystemd/lib/pkgconfig /opt/libsystemd/include/systemd && \
    cp build/libsystemd.a /opt/libsystemd/lib/ && \
    cp src/systemd/sd-*.h src/systemd/_sd-common.h /opt/libsystemd/include/systemd/ && \
    printf 'Name: systemd\nDescription: static libsystemd\nVersion: %s\n' \
        "$(meson introspect build --projectinfo | sed 's/.*"version": "\([^"]*\)".*/\1/')" \
        > /opt/libsystemd/lib/pkgconfig/systemd.pc

FROM debian:bookworm AS build
ARG TAG
ARG TARGETARCH
RUN test -n "$TAG" || (echo "TAG not set" && false)

ENV DEBIAN_FRONTEND=noninteractive
RUN apt update && apt install -y build-essential cmake flex bison curl pkg-config libyaml-dev libssl-dev \
        libcap-dev liblz4-dev liblzma-dev

COPY --from=libsystemd /opt/libsystemd /opt/libsystemd

RUN mkdir /tmp/build && chown nobody:nogroup /tmp/build

USER nobody
WORKDIR /tmp/build

RUN curl -L "https://api.github.com/repos/fluent/fluent-bit/tarball/$TAG" | tar -xzf -

# Notes on the less obvious options:
# - FLB_LIBYAML_LIBRARY / LIBM_LIBRARIES: Fluent Bit (>= 5.2) and its bundled
#   LuaJIT locate these with find_library() and link the full path found, which
#   is the shared object; point them at the static archives.
# - WAMR_BUILD_TARGET: the WASM runtime otherwise guesses from the host kernel,
#   which is wrong for 32-bit builds on 64-bit runners.
# - JOURNALD_LIBRARY: libsystemd.a plus what it needs. zstd is resolved by
#   Fluent Bit's bundled copy (libzstd_static) to avoid duplicate symbols.
# - FLB_HAVE_SYSTEMD_JOURNAL_NAMESPACE: preset because cmake's own probe cannot
#   link against the libzstd_static target name and so wrongly reports "no".
RUN cd fluent*/build && \
    libdir="/usr/lib/$(gcc -print-multiarch)" && \
    case "$TARGETARCH" in \
        amd64) wamr_target=X86_64 ;; \
        386)   wamr_target=X86_32 ;; \
        arm64) wamr_target=AARCH64 ;; \
        arm)   wamr_target=ARM ;; \
        *)     echo "Unsupported TARGETARCH: $TARGETARCH" && exit 1 ;; \
    esac && \
    PKG_CONFIG_PATH=/opt/libsystemd/lib/pkgconfig cmake \
        -DFLB_DEBUG=No -DFLB_RELEASE=Yes -DFLB_SHARED_LIB=No \
        -DFLB_LUAJIT=Yes -DFLB_WASM=Yes -DWAMR_BUILD_TARGET="$wamr_target" \
        -DFLB_LIBYAML_LIBRARY="$libdir/libyaml.a" \
        -DLIBM_LIBRARIES="$libdir/libm.a" \
        -DJOURNALD_INCLUDE_DIR=/opt/libsystemd/include \
        -DJOURNALD_LIBRARY:STRING="/opt/libsystemd/lib/libsystemd.a;libzstd_static;$libdir/liblzma.a;$libdir/liblz4.a;$libdir/libcap.a" \
        -DFLB_HAVE_SYSTEMD_JOURNAL_NAMESPACE=1 \
        -DCMAKE_FIND_LIBRARY_SUFFIXES=".a" -DBUILD_SHARED_LIBS=OFF \
        -DCMAKE_EXE_LINKER_FLAGS="-static" -DOPENSSL_USE_STATIC_LIBS=Yes \
        -DCMAKE_C_FLAGS="-fcommon -I/opt/libsystemd/include" .. && \
    make -j"$(nproc)" && \
    strip bin/fluent-bit && \
    cp bin/fluent-bit "/tmp/fluent-bit-${TAG}-${TARGETARCH}"

FROM scratch
ARG TAG
ARG TARGETARCH

COPY --from=build --chown=0:0 /tmp/fluent-bit-${TAG}-${TARGETARCH} /

ENTRYPOINT [ "/fluent-bit-${TAG}-${TARGETARCH}" ]
