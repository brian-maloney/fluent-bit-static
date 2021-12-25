FROM debian:latest as build
ARG TAG
ARG TARGETARCH
RUN test -n "$TAG" || (echo "TAG not set" && false)

ENV DEBIAN_FRONTEND=noninteractive
RUN apt update && apt install -y build-essential cmake flex bison curl libsystemd-dev

RUN mkdir /tmp/build && chown nobody:nogroup /tmp/build

USER nobody
WORKDIR /tmp/build

RUN curl -L "https://api.github.com/repos/fluent/fluent-bit/tarball/$TAG" | tar -xzf -

RUN cd fluent*/build && \
    cmake -DFLB_SHARED_LIB=No -DCMAKE_FIND_LIBRARY_SUFFIXES=".a" -DBUILD_SHARED_LIBS=OFF -DCMAKE_EXE_LINKER_FLAGS="-static" .. && \
    make && \
    strip bin/fluent-bit && \
    cp bin/fluent-bit "/tmp/fluent-bit-${TAG}-${TARGETARCH}"

FROM scratch
ARG TAG
ARG TARGETARCH

COPY --from=build --chown=0:0 /tmp/fluent-bit-${TAG}-${TARGETARCH} /

ENTRYPOINT [ "/fluent-bit-${TAG}-${TARGETARCH}" ]
