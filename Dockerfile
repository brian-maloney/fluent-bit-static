FROM debian:bookworm as build
ARG TAG
ARG TARGETARCH
RUN test -n "$TAG" || (echo "TAG not set" && false)

ENV DEBIAN_FRONTEND=noninteractive
RUN apt update && apt install -y build-essential cmake flex bison curl libyaml-dev libssl-dev

RUN mkdir /tmp/build && chown nobody:nogroup /tmp/build

USER nobody
WORKDIR /tmp/build

RUN curl -L "https://api.github.com/repos/fluent/fluent-bit/tarball/$TAG" | tar -xzf -

RUN cd fluent*/build && \
    cmake -DFLB_WASM=No -DFLB_LUAJIT=No -DFLB_DEBUG=No -DFLB_RELEASE=Yes -DFLB_SHARED_LIB=No -DCMAKE_FIND_LIBRARY_SUFFIXES=".a" -DBUILD_SHARED_LIBS=OFF -DCMAKE_EXE_LINKER_FLAGS="-static" -DOPENSSL_USE_STATIC_LIBS=Yes -DCMAKE_C_FLAGS="-fcommon" .. && \
    make && \
    strip bin/fluent-bit && \
    cp bin/fluent-bit "/tmp/fluent-bit-${TAG}-${TARGETARCH}"

FROM scratch
ARG TAG
ARG TARGETARCH

COPY --from=build --chown=0:0 /tmp/fluent-bit-${TAG}-${TARGETARCH} /

ENTRYPOINT [ "/fluent-bit-${TAG}-${TARGETARCH}" ]
