# Changelog

## 29.3-shairport20

**Major: migrated to the official `owntone/owntone:latest` (29.3) base image.**

Replaces the deprecated `linuxserver/daapd` base, its s6-overlay init, and the
symlink-config chain that required constant self-healing workarounds. The
official image is Alpine + OpenRC; the addon now uses OpenRC services for all
lifecycle management.

- **Base image**: `owntone/owntone:latest` (OwnTone 29.3, up from 28.10).
- **Init system**: BusyBox `/sbin/init` + OpenRC (was s6-overlay). All
  services — owntone, avahi-daemon, dbus, shairport-sync, and a new
  `owntone-config` renderer — are managed via `/etc/init.d/` and the
  `default` runlevel.
- **Config path**: `/etc/owntone/owntone.conf` (was `/etc/owntone.conf`,
  no more `.orig` symlink chain).
- **Config rendering**: new `owntone-config` OpenRC service replaces the old
  `90-homeassistant` cont-init.d script. Runs before owntone, renders config
  from the upstream 29.3 template + add-on options, persists to `/share`.
- **shairport-sync**: new `shairport-sync` OpenRC service replaces the s6
  `svc-shairport` longrun. Same pipe-backend AirPlay ingress, same
  ignore_volume_control + volume_max_db=0 behavior.
- **User**: `owntone` (was `abc` — the linuxserver convention).
- **Dropped**: avahi-dnsconfd dependency (it rewrote resolv.conf; replaced
  with direct avahi-daemon dependency). No more spotify-section self-heal,
  no more airplay_shared brace-fix awk (those were 28.10-specific bugs).
- **New option**: `general.start_buffer_ms` (default 2250, range 0–10000) —
  reduces AirPlay startup latency. Supported by OwnTone 29.x (was absent
  from 28.10).

## 28.10-shairport19

- New option `general.high_resolution_clock` (default: enabled, matching the
  template default) to toggle OwnTone's high-resolution playback clock.
  Only disable on unusual platforms if you experience audio drop-outs.

## 28.10-shairport18

- Silence the libmdns WARN spam (`dropping truncated packet` /
  `couldn't parse packet`) that flooded the app log on any LAN with active
  mDNS. OwnTone's mDNS advertiser is the Rust libmdns crate using env_logger,
  so it ignores OwnTone's own loglevel — set `RUST_LOG=warn,libmdns=error`
  via the app's environment key.

## 28.10-shairport17

- Actually disable IPv6: the old sed targeted `ipv6 = yes`, which upstream
  28.10 no longer ships (it is `# ipv6 = no`, commented = enabled). Now
  uncomments the explicit `ipv6 = no`, silencing the fe80:: mDNS warnings.
  No-op on the IPv4-centric LAN.
- Removed the stale `shairport-sync-audio`/`shairport-sync-metadata` symlinks
  from the music dir (left over from an early pipe naming iteration) that
  caused scan-skip warnings on every library scan.

## 28.10-shairport16

- Fix the artwork/DACP cache: OwnTone 28.10 keeps it as `daap.db` inside
  `cache_dir`, whose template default `/var/cache/owntone` is not writable by
  the `abc` user — the cache was disabled at runtime ("Could not open
  '/var/cache/owntone/daap.db'"). Both the Dockerfile and linuxserver's init
  seds still targeted the 28.9-era `cache.db` filename, so nothing rewrote it.
  `cache_dir` is now set to `/share/owntone/dbase_and_logs` both at build time
  and at every start (after the persisted-config overlay, with an insert
  fallback for legacy configs that have no `cache_dir` line at all).

## 28.10-shairport15

- Add `translations/en.yaml`: friendly names and descriptions for every
  configuration option, shown in the app's Configuration tab (docs moved out of
  the README table).
- Rewrite README: document the shairport-sync AirPlay ingress feature, drop the
  outdated "host networking crashes" warning (host networking is required and
  stable), remove armv7/Spotify references.

## 28.10-shairport14

- Fix config init: always start from `owntone.conf.orig`, then overlay the
  persisted `/share/owntone/dbase_and_logs/owntone.conf` if present.
- Persist the effective `owntone.conf` to `/share` on startup.
- Self-heal a corrupted persisted config: remove any active (non-commented)
  `spotify {}` section remnant that broke parsing as part of `airplay_shared`.

## 28.10-shairport13

- Make the metadata pipe optional via `shairport.metadata_enabled` (default
  false). OwnTone reads AirPlay volume (`pvol`) from the metadata pipe and
  applies it to its master volume — with no metadata pipe, the room volume
  finally stays locked regardless of the phone's volume slider. Trade-off: no
  now-playing metadata from the AirPlay source.

## 28.10-shairport11 / shairport12

- Volume-lock attempts: `ignore_volume_control = "yes"` plus
  `volume_max_db = 0.0` in shairport-sync (the pipe backend attenuates in
  software, so the ceiling must be pinned). Turned out insufficient — the real
  path was `pvol` via the metadata pipe (fixed in shairport13).

## 28.10-shairport9 / shairport10

- Remove the `sleep infinity > pipe` holder: it kept the pipe perpetually open,
  making OwnTone's `pipe_autostart` re-queue the AirPlay pipe track after every
  queue/clear. shairport-sync opens the pipe itself when a stream starts.
- Always clear the OwnTone queue before playing a stream (HA-side automation).

## 28.10-shairport8

- Add a shairport-sync **metadata pipe** (`AirPlay.metadata`) for now-playing
  info (title/artist/cover) from the AirPlay source.
- Settings cleanup: remove the `ports:`/`ports_description:` block (ignored
  under host networking) and drop the deprecated `armv7` arch.

## 28.10-shairport7

- Switch to `host_network: true`: in bridge mode the container sat on the
  isolated Docker subnet and AirPlay/mDNS multicast never reached the LAN, so
  phones couldn't discover the "Multiroom" receiver. (The upstream README's
  host-mode crash warning is outdated.)

## 28.10-shairport5 / shairport6

- Move the shairport-sync service to the s6-rc.d layout used by the linuxserver
  base image (`svc-shairport` with `type=longrun`, `dependencies.d/init-services`,
  registered in `user/contents.d`) — the service never started under the old
  `/etc/services.d/` path.

## 28.10-shairport4

- Add `ARG CACHEBUST` and a `shairport-sync -V` check to the build: Supervisor
  rebuilds were served from stale Docker layer cache and silently skipped
  installing shairport-sync.

## 28.10-shairport2 / shairport3

- Fix the `airplay_shared` config block: the old seds uncommented the opening
  brace and ports but never the closing `#}`, so the block swallowed every
  section below it (including spotify) — OwnTone 28.10 FATAL
  `no such option 'spotify'`. Opening, ports and closing brace are now all
  handled (via awk).
- Remove obsolete Spotify option handling from the init script (28.10 dropped
  `use_libspotify`); the default commented spotify section is left untouched.

## 28.10-shairport1

- Pin the base image to `linuxserver/daapd:28.10.20250118` — `latest` is an
  empty/deprecated manifest with no platform images (broke the aarch64 build).
  This also upgrades OwnTone 28.6 → 28.10.
- Add shairport-sync as an AirPlay **receiver**: phone → shairport-sync → raw
  PCM pipe (`/share/owntone/music/AirPlay`, fixed 44100/S16_LE/2ch) → OwnTone
  pipe input → redistributed to all enabled AirPlay outputs. New `shairport`
  option group.
- Point `repository.yml` at this fork.
