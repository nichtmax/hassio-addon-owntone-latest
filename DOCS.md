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
