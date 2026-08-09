# OwnTone App for Home Assistant

This Home Assistant App runs OwnTone 29.3 with a focused Shairport Sync 5.2.1
receiver for multi-room AirPlay ingress:

`AirPlay source → Shairport Sync → PCM pipe → OwnTone → selected outputs`

The App uses host networking for mDNS/AirPlay discovery and stores its library,
database, logs, generated configuration, and pipes below `/share/owntone`.

## Installation

Add this repository in **Settings → Apps → App Store → Repositories**:

`https://github.com/nichtmax/hassio-addon-owntone-latest`

For local development, clone it as `/local_apps/owntone-server` (called
`/addons/owntone-server` before Home Assistant 2026.7) and reload the App Store.
Do not run the repository and local builds simultaneously: both bind the same
host ports and use the same `/share/owntone` data.

## Configuration

The Configuration tab exposes OwnTone's user-facing settings with typed fields
and inline descriptions. Runtime identity, storage paths, library root, pipe
paths, and service ports are managed by the App.

Shairport Sync is intentionally limited to the receiver name/password,
metadata forwarding, volume handling, and the PCM rate/format shared with
OwnTone. See [DOCS.md](DOCS.md) for details and examples.

## Development

Run the static and renderer test suite with:

```sh
./tests/run.sh
```

Audit the current upstream OwnTone template with:

```sh
./tests/audit-upstream.sh
```

The suite checks shell code, schema/translation parity, the curated upstream
OwnTone option catalog, safe escaping, all supported PCM pairs, metadata/volume
combinations, and invalid input rejection.

## Credits

Based on the official [OwnTone image](https://hub.docker.com/r/owntone/owntone)
and [Shairport Sync](https://github.com/mikebrady/shairport-sync). This fork was
derived from `mynameisdaniel32/hassio-addon-owntone-latest`.
