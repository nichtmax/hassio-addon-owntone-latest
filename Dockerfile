# Pin to a multi-arch manifest (amd64+arm64). linuxserver/daapd:latest is an
# empty/deprecated manifest with no platform images, which broke the build.
# 28.10.20250118 = OwnTone 28.10, newest tag with arm64 (aarch64) support.
FROM linuxserver/daapd:28.10.20250118

ARG BUILD_ARCH

# jq: parse add-on options in the init script.
# shairport-sync: AirPlay receiver for phone -> pipe -> OwnTone ingress.
#   Fall back to Alpine edge/community if the base image's repos don't carry it.
# CACHEBUST forces Docker to re-run this layer (and the COPY below) instead of
# serving a stale cached image that predates shairport-sync.
ARG CACHEBUST=2
RUN echo "cachebust: ${CACHEBUST}" \
    && apk add --no-cache jq \
    && (apk add --no-cache shairport-sync \
        || apk add --no-cache --repository=https://dl-cdn.alpinelinux.org/alpine/edge/community shairport-sync) \
    && shairport-sync -V

RUN sed -i -e s#"ipv6 = yes"#"ipv6 = no"#g /etc/owntone.conf.orig \
    && sed -i s#/srv/music#/share/owntone/music#g /etc/owntone.conf.orig \
    && sed -i s#/var/cache/owntone/songs3.db#/share/owntone/dbase_and_logs/songs3.db#g /etc/owntone.conf.orig \
    && sed -i s#/var/cache/owntone/cache.db#/share/owntone/dbase_and_logs/cache.db#g /etc/owntone.conf.orig \
    && sed -i s#/var/log/owntone.log#/share/owntone/dbase_and_logs/owntone.log#g /etc/owntone.conf.orig \
    && sed -i "/websocket_port\ =/ s/# *//" /etc/owntone.conf.orig \
    && sed -i "/trusted_networks\ =/ s/# *//" /etc/owntone.conf.orig \
    && sed -i "/pipe_autostart\ =/ s/# *//" /etc/owntone.conf.orig \
    && sed -i "/type\ =/ s/#/ /" /etc/owntone.conf.orig \
    && sed -i 's/\(type =\).*/\1 "pulseaudio"/' /etc/owntone.conf.orig

# airplay_shared: the old seds uncommented the opening "#airplay_shared {" and
# the two port lines but NEVER the closing "#}", so the block swallowed every
# section below it (including spotify) until the next "}" -> OwnTone 28.10 FATAL
# "config: [airplay_shared:969] no such option 'spotify'". Uncomment the opening
# and both port lines, set the ports, then close the block with awk (uncomment
# the first "#}" that appears after "airplay_shared {").
RUN sed -i 's/^#airplay_shared {/airplay_shared {/' /etc/owntone.conf.orig \
    && sed -i 's/^#       control_port = 0/        control_port = 3690/' /etc/owntone.conf.orig \
    && sed -i 's/^#       timing_port = 0/        timing_port = 3691/' /etc/owntone.conf.orig \
    && awk 'BEGIN{inb=0} /^airplay_shared \{/{inb=1} inb && /^#\}/{sub(/^#\}/,"}"); inb=0} {print}' /etc/owntone.conf.orig > /etc/owntone.conf.tmp \
    && mv /etc/owntone.conf.tmp /etc/owntone.conf.orig

ADD 90-homeassistant /etc/cont-init.d/90-homeassistant

RUN chmod +x /etc/cont-init.d/90-homeassistant

# shairport-sync service (s6-overlay, linuxserver base).
COPY rootfs /
