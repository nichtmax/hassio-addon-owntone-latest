FROM linuxserver/daapd:latest

ARG BUILD_ARCH

# jq: parse add-on options in the init script.
# shairport-sync: AirPlay receiver for phone -> pipe -> OwnTone ingress.
#   Fall back to Alpine edge/community if the base image's repos don't carry it.
RUN apk add --no-cache jq \
    && (apk add --no-cache shairport-sync \
        || apk add --no-cache --repository=https://dl-cdn.alpinelinux.org/alpine/edge/community shairport-sync)

RUN sed -i -e s#"ipv6 = yes"#"ipv6 = no"#g /etc/owntone.conf.orig \
    && sed -i s#/srv/music#/share/owntone/music#g /etc/owntone.conf.orig \
    && sed -i s#/var/cache/owntone/songs3.db#/share/owntone/dbase_and_logs/songs3.db#g /etc/owntone.conf.orig \
    && sed -i s#/var/cache/owntone/cache.db#/share/owntone/dbase_and_logs/cache.db#g /etc/owntone.conf.orig \
    && sed -i s#/var/log/owntone.log#/share/owntone/dbase_and_logs/owntone.log#g /etc/owntone.conf.orig \
    && sed -i "/websocket_port\ =/ s/# *//" /etc/owntone.conf.orig \
    && sed -i "/trusted_networks\ =/ s/# *//" /etc/owntone.conf.orig \
    && sed -i "/pipe_autostart\ =/ s/# *//" /etc/owntone.conf.orig \
    && sed -i "/airplay_shared/ s/# *//" /etc/owntone.conf.orig \
    && sed -i "/control_port\ =/ s/#/ /" /etc/owntone.conf.orig \
    && sed -i "/timing_port\ =/ s/#/ /" /etc/owntone.conf.orig \
    && sed -i "/timing_port/{N;s/\n#/\n/}" /etc/owntone.conf.orig \
    && sed -i "s/\(control_port =\).*/\1 3690/" /etc/owntone.conf.orig \
    && sed -i "s/\(timing_port =\).*/\1 3691/" /etc/owntone.conf.orig \
    && sed -i "/type\ =/ s/#/ /" /etc/owntone.conf.orig \
    && sed -i 's/\(type =\).*/\1 "pulseaudio"/' /etc/owntone.conf.orig

ADD 90-homeassistant /etc/cont-init.d/90-homeassistant

RUN chmod +x /etc/cont-init.d/90-homeassistant

# shairport-sync service (s6-overlay, linuxserver base).
COPY rootfs /
