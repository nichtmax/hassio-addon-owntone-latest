# OwnTone configuration

All settings are managed from the App's **Configuration** tab. The effective
files are regenerated on every start and copied to these diagnostic locations:

- `/share/owntone/dbase_and_logs/owntone.conf`
- `/share/owntone/dbase_and_logs/shairport-sync.conf`

Manual edits to those files are intentionally overwritten. The library root is
fixed at `/share/owntone/music`; database, cache, backup, and logs are stored in
`/share/owntone/dbase_and_logs`.

## OwnTone sections

The App exposes the user-facing settings from the upstream OwnTone template:

- `general` and `library` for server, indexing, metadata, playlist, rating, and
  transcoding behavior.
- `audio`, `alsa`, and `fifo` for optional local outputs.
- `airplay_shared`, `airplay`, `chromecast`, and `rcp` for network outputs.
- `spotify`, `mpd`, `sqlite`, and `streaming` for their respective subsystems.

Named device sections are lists. Names must exactly match the advertised device
name, including capitalization.

## Shairport Sync pipe

Shairport Sync exists only to receive AirPlay and write raw stereo PCM to
`/share/owntone/music/AirPlay`. OwnTone watches this pipe and starts playback on
the selected outputs. The path, backend, and stereo channel count are fixed.

The following options are supported:

- `name`: advertised AirPlay receiver name.
- `password`: optional receiver password.
- `metadata_enabled`: creates `AirPlay.metadata` and forwards title, artist,
  artwork, and source-volume messages.
- `ignore_volume_control`: when enabled, Shairport does not attenuate PCM based
  on the source volume. Metadata volume messages can still change OwnTone's
  player volume when metadata forwarding is enabled.
- `allow_session_interruption`: allows a new Classic AirPlay source to replace
  the current session. AirPlay 2 manages interruption independently.
- `session_timeout`: seconds without source audio before an abandoned session
  is released; the minimum and default are 60 seconds.
- `pipe_sample_rate`: 44100, 48000, 88200, or 96000 Hz.
- `pipe_sample_format`: `S16_LE` or `S32_LE`.

Rate and format are written to both configurations. Invalid or mismatched values
stop the App during configuration rendering instead of producing distorted
audio.

Example:

```yaml
shairport:
  name: Multiroom
  password: ""
  metadata_enabled: false
  ignore_volume_control: true
  allow_session_interruption: false
  session_timeout: 60
  pipe_sample_rate: 44100
  pipe_sample_format: S16_LE
```

Shairport diagnostics are always enabled. Statistics and elapsed-time markers
are written to the App log, and diagnostic verbosity follows `general.loglevel`:
`fatal`, `log`, and `warning` map to 0; `info` to 1; `debug` to 2; and `spam` to
3. This keeps both daemons on one App-wide logging control.

## Volume behavior

| Metadata | Ignore source volume | Result |
|---|---|---|
| Off | On | PCM remains at full level; control room volume in OwnTone. |
| Off | Off | The AirPlay source attenuates the PCM stream. |
| On | On | PCM remains full level, but metadata can change OwnTone player volume. |
| On | Off | Source attenuation and metadata-driven OwnTone volume both apply. |

## Networking

Host networking is required for multicast discovery. OwnTone binds its web/API
and DAAP service on 3689, websocket service on 3688, MPD on 6600, and fixed
AirPlay output ports on 3690/3691. Shairport Sync uses its standard AirPlay
receiver ports. Avoid running another instance on the same host concurrently.

## Automatic AirPlay recovery

OpenRC supervises Shairport Sync and restarts a crashed receiver after 10
seconds. After a 60-second startup grace period, it checks localhost:5000 every
30 seconds using a non-playing RTSP OPTIONS request. Three failed probes, each
bounded to three seconds and separated by five seconds, trigger receiver-only
recovery. A successful retry cancels recovery. Checks do not start a stream,
change the queue, or alter room selection. OwnTone's existing Supervisor HTTP
watchdog remains enabled for failures of the whole server.

Receiver stdout/stderr are sent to the App log. Recovery messages identify
failed AirPlay handshakes. The existing session interruption setting is
preserved. A successful OPTIONS response verifies the control endpoint, not
sender Wi-Fi, multicast discovery, or end-to-end audio playback.

Deployment: refresh the App store and update OwnTone to the latest version.
The update briefly restarts the App; no Home Assistant Core restart is needed.
Keep an App backup before updating. To roll back, restore that backup or rebuild
the previous source revision. Receiver health checks require no new options.

## Live updates in the Home Assistant sidebar

The sidebar uses an ingress-only Nginx listener on port 3692. It accepts requests
only from Home Assistant Supervisor (`172.30.32.2`), forwards HTTP to OwnTone
on 3689, and forwards `/ws` upgrades to its notify service on 3688. A small
script loaded before the app rewrites notify sockets to the current ingress
path and origin, including HTTPS/WSS. Direct access on port 3689 stays native.

After updating, close and reopen the sidebar page to load the new entrypoint.
No additional port forwarding or Home Assistant Core restart is required.

Proxy development test (disposable Alpine with nginx, python3 and
py3-websocket-client): `python3 tests/integration-ingress.py`. The test binds
ports 3688, 3689 and 3692 and must not run alongside a live OwnTone instance.
The regular suite also requires Node.js for the ingress URL tests.

## macOS AirPlay receivers

The App defaults OwnTone’s `general.user_agent` to `AirPlay/490.16`. macOS 27
can reject `owntone/29.3` with 403 and “sender not admissible” before pairing
or streaming starts. The optional General client identifier setting overrides
this default. It applies to OwnTone’s outgoing requests, including AirPlay
and HTTP sources; it does not change receiver access settings.

Rollback: restore the pre-update App backup, or set the client identifier to
`owntone/29.3` and restart the App to restore the previous identifier.

## Receiver health checks during playback

Classic Shairport 5.2.1 rejects new TCP connections while a sender owns the
session and interruption is disabled. The watchdog therefore checks Linux TCP
state for established connections on receiver port 5000 before probing OPTIONS,
and again after a failed probe to cover a sender connecting during the check.
Idle receivers still require a valid RTSP response; three failures trigger
receiver-only recovery. IPv4 and IPv6 sessions are recognized.

An established connection proves session presence, not audio flow. Stale sessions
rely on Shairport's timeout/TCP keepalive; crashes still use OpenRC supervision.
The watchdog never reads the audio FIFO, which would steal audio from OwnTone.
