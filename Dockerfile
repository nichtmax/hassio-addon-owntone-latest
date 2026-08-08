# OwnTone 29.x official image (Alpine + OpenRC). Replaces the deprecated
# linuxserver/daapd base. Multi-arch (amd64 + arm64). OpenRC manages owntone
# + avahi + dbus; we add shairport-sync and a config-renderer as OpenRC
# services that run before owntone.
FROM owntone/owntone:latest

ARG BUILD_ARCH

# jq: parse add-on options in the config renderer.
# shairport-sync: AirPlay receiver for phone -> pipe -> OwnTone ingress.
#   Fall back to Alpine edge/community if the base image's repos don't carry it.
ARG CACHEBUST=9
RUN echo "cachebust: ${CACHEBUST}" \
    && apk add --no-cache jq \
    && (apk add --no-cache shairport-sync \
        || apk add --no-cache --repository=https://dl-cdn.alpinelinux.org/alpine/edge/community shairport-sync) \
    && shairport-sync -V

# Config renderer: generates /etc/owntone/owntone.conf from add-on options
# before the owntone service starts. Registered as an OpenRC service with
# owntone depending on it.
ADD owntone-config.init /etc/init.d/owntone-config
RUN chmod +x /etc/init.d/owntone-config \
    && mkdir -p /etc/runlevels/default \
    && ln -sf /etc/init.d/owntone-config /etc/runlevels/default/owntone-config

# Patch owntone's own init to depend on owntone-config (instead of
# avahi-dnsconfd, which rewrites resolv.conf — not wanted in an HA addon).
RUN sed -i 's/^depend() {$/depend() {\n    need owntone-config avahi-daemon/' \
        /etc/init.d/owntone \
    && sed -i '/need avahi-dnsconfd/d' /etc/init.d/owntone

# shairport-sync service: AirPlay receiver that pipes PCM into OwnTone.
ADD shairport-sync.init /etc/init.d/shairport-sync
RUN chmod +x /etc/init.d/shairport-sync \
    && ln -sf /etc/init.d/shairport-sync /etc/runlevels/default/shairport-sync

# Ensure dbus + avahi-daemon are in the default runlevel (owntone needs avahi
# for AirPlay discovery; the base image only has owntone+syslog there).
RUN ln -sf /etc/init.d/dbus /etc/runlevels/default/dbus \
    && ln -sf /etc/init.d/avahi-daemon /etc/runlevels/default/avahi-daemon
