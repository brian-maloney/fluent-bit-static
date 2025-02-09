FROM debian:bookworm as build
ARG TAG
ARG TARGETARCH
RUN test -n "$TAG" || (echo "TAG not set" && false)

USER nobody
WORKDIR /tmp/build

RUN echo "test" > "/tmp/fluent-bit-${TAG}-${TARGETARCH}"

FROM scratch
ARG TAG
ARG TARGETARCH

COPY --from=build --chown=0:0 /tmp/fluent-bit-${TAG}-${TARGETARCH} /

ENTRYPOINT [ "/fluent-bit-${TAG}-${TARGETARCH}" ]
