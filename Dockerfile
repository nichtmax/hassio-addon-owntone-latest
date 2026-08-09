FROM owntone/owntone:29.3 AS shairport-build

ARG SHAIRPORT_SYNC_VERSION=5.2.1
ARG SHAIRPORT_SYNC_SHA256=8f97d1a6e045bc3765b10d0cd64abe467eba343af89fa1e158f7fa28b73c4ab6

RUN apk add --no-cache \
        autoconf \
        automake \
        avahi-dev \
        build-base \
        curl \
        ffmpeg-dev \
        libconfig-dev \
        libtool \
        openssl-dev \
        pkgconf \
        popt-dev

WORKDIR /tmp/shairport-sync
RUN curl -fsSL \
        "https://github.com/mikebrady/shairport-sync/archive/refs/tags/${SHAIRPORT_SYNC_VERSION}.tar.gz" \
        -o source.tar.gz \
    && printf '%s  %s\n' "${SHAIRPORT_SYNC_SHA256}" source.tar.gz | sha256sum -c - \
    && mkdir source \
    && tar -xzf source.tar.gz -C source --strip-components=1

WORKDIR /tmp/shairport-sync/source
RUN autoreconf -fi \
    && ./configure \
        --prefix=/usr \
        --sysconfdir=/etc \
        --with-avahi \
        --with-ffmpeg \
        --with-metadata \
        --with-metadata-pipe \
        --with-pipe \
        --with-ssl=openssl \
    && make -j2 \
    && make DESTDIR=/tmp/shairport-install install

# OwnTone 29.x official image (Alpine + OpenRC). OpenRC manages OwnTone,
# Avahi, D-Bus, the deterministic renderer, and the focused Shairport bridge.
FROM owntone/owntone:29.3

ARG BUILD_ARCH
ARG BUILD_VERSION=dev

LABEL \
    io.hass.version="${BUILD_VERSION}" \
    io.hass.type="app" \
    io.hass.arch="${BUILD_ARCH}" \
    org.opencontainers.image.title="OwnTone Home Assistant App" \
    org.opencontainers.image.description="OwnTone with a focused Shairport Sync pipe receiver" \
    org.opencontainers.image.source="https://github.com/nichtmax/hassio-addon-owntone-latest" \
    org.opencontainers.image.licenses="MIT" \
    org.opencontainers.image.version="${BUILD_VERSION}"

# Install only the runtime libraries required by the focused source build.
RUN apk add --no-cache \
        libconfig \
        jq \
        popt

COPY --from=shairport-build /tmp/shairport-install/usr/bin/shairport-sync \
    /usr/bin/shairport-sync
RUN shairport-sync -V | grep -Eq '^5\.2\.1([[:space:]-]|$)'

COPY --chmod=755 render-config.sh /usr/local/bin/render-owntone-config
COPY render-owntone.jq render-shairport.jq /usr/local/lib/owntone-addon/

# Config renderer: generates /etc/owntone/owntone.conf from add-on options
# before the owntone service starts. Registered as an OpenRC service with
# owntone depending on it.
COPY --chmod=755 owntone-config.init /etc/init.d/owntone-config
RUN mkdir -p /etc/runlevels/default \
    && ln -sf /etc/init.d/owntone-config /etc/runlevels/default/owntone-config

# Patch owntone's own init to depend on owntone-config (instead of
# avahi-dnsconfd, which rewrites resolv.conf — not wanted in an HA addon).
RUN sed -i 's/^depend() {$/depend() {\n    need owntone-config avahi-daemon/' \
        /etc/init.d/owntone \
    && sed -i '/need avahi-dnsconfd/d' /etc/init.d/owntone

# shairport-sync service: AirPlay receiver that pipes PCM into OwnTone.
COPY --chmod=755 shairport-sync.init /etc/init.d/shairport-sync
RUN ln -sf /etc/init.d/shairport-sync /etc/runlevels/default/shairport-sync

# Ensure dbus + avahi-daemon are in the default runlevel (owntone needs avahi
# for AirPlay discovery; the base image only has owntone+syslog there).
RUN ln -sf /etc/init.d/dbus /etc/runlevels/default/dbus \
    && ln -sf /etc/init.d/avahi-daemon /etc/runlevels/default/avahi-daemon
