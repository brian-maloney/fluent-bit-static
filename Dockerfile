FROM scratch
ARG TAG
ARG TARGETARCH

RUN echo "test" > /fluent-bit-${TAG}-${TARGETARCH}

ENTRYPOINT [ "/fluent-bit-${TAG}-${TARGETARCH}" ]
