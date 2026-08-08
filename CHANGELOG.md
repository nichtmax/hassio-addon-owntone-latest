# Changelog

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
