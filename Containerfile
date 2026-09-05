ARG ALPINE_VERSION=3
ARG SOLOIST_URL=https://soloist-builds.spotifycdn.com/soloist_release_x86_64.tar.gz

# Build stage (Debian).
# This will download the Soloist binary.
# All the necessary system dependencies will be installed as well.
# Soloist binary will be inspected for runtime dependencies as it relies on
# glibc 2.14 and can't run with musl alone.
# All the necessary library files (as well as Pipewire client config) will be
# collected for injecting into the final image.
FROM debian:trixie-slim AS glibc-runtime

ARG SOLOIST_URL

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        libatomic1 \
        libpipewire-0.3-0 \
        libpulse0 \
        pax-utils \
        pipewire-bin \
        tar \
    && curl --fail --location --silent --show-error "$SOLOIST_URL" -o /tmp/soloist.tar.gz \
    && tar -xzf /tmp/soloist.tar.gz -C /tmp \
    && test -x /tmp/soloist \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /runtime/lib64 \
    && lddtree -l /tmp/soloist | xargs -r -I{} cp --parents {} /runtime \
    && lddtree -l /usr/lib/x86_64-linux-gnu/libpipewire-0.3.so.0 | xargs -r -I{} cp --parents {} /runtime \
    && lddtree -l /usr/lib/x86_64-linux-gnu/libpulse.so.0 | xargs -r -I{} cp --parents {} /runtime \
    && for library in \
        /usr/lib/x86_64-linux-gnu/pipewire-0.3/libpipewire-module-rt.so \
        /usr/lib/x86_64-linux-gnu/pipewire-0.3/libpipewire-module-protocol-native.so \
        /usr/lib/x86_64-linux-gnu/pipewire-0.3/libpipewire-module-client-node.so \
        /usr/lib/x86_64-linux-gnu/pipewire-0.3/libpipewire-module-client-device.so \
        /usr/lib/x86_64-linux-gnu/pipewire-0.3/libpipewire-module-adapter.so \
        /usr/lib/x86_64-linux-gnu/pipewire-0.3/libpipewire-module-metadata.so \
        /usr/lib/x86_64-linux-gnu/pipewire-0.3/libpipewire-module-session-manager.so \
        /usr/lib/x86_64-linux-gnu/spa-0.2/support/libspa-support.so \
        /usr/lib/x86_64-linux-gnu/spa-0.2/audioconvert/libspa-audioconvert.so; do \
            lddtree -l "$library" | xargs -r -I{} cp --parents {} /runtime; \
        done \
    && cp --parents /usr/share/pipewire/client.conf /runtime \
    && rm -f /runtime/tmp/soloist \
    && rmdir /runtime/tmp


# Run stage (Alpine).
FROM alpine:${ALPINE_VERSION}

RUN apk add --no-cache ca-certificates

# Inject the system dependencies collected in the previous stage.
COPY --from=glibc-runtime /runtime/ /
COPY --chmod=0755 --from=glibc-runtime /tmp/soloist /usr/local/bin/soloist
COPY --chmod=0755 soloist-entrypoint /usr/local/bin/soloist-entrypoint

RUN mkdir -p /data

VOLUME ["/data"]

ENV SOLOIST_DATA_DIR=/data \
    SOLOIST_CACHE_DIR=/tmp/soloist-cache \
    LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu:/lib/x86_64-linux-gnu

ENTRYPOINT ["/usr/local/bin/soloist-entrypoint"]
