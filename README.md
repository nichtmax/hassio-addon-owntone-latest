# Home Assistant OwnTone Add-on (with AirPlay multiroom ingress)

Run [OwnTone](https://owntone.github.io/owntone-server/) 29.3 — a DAAP (iTunes) media server with AirPlay, Chromecast, MPD and internet radio support — as a Home Assistant add-on. Based on the official [owntone/owntone](https://hub.docker.com/r/owntone/owntone) image.

**What this fork adds:**

- **Built-in shairport-sync AirPlay receiver.** AirPlay from your phone to the add-on ("Multiroom" by default); shairport-sync writes raw PCM into a pipe that OwnTone reads and redistributes to all enabled AirPlay outputs. Phone → every room, in sync.
- **OwnTone 29.3** (via the official Docker image, replacing the deprecated linuxserver/daapd base).
- **Host networking**, required for AirPlay/mDNS discovery of the receiver.

## Supported architectures

`aarch64` and `amd64`. Tested on aarch64 (HAOS).

## Installation

In Home Assistant go to **Settings → Apps → App Store**, click the three dots in the top right corner → **Repositories**, add `https://github.com/nichtmax/hassio-addon-owntone-latest` and confirm. The **Owntone server** app appears in the list; install it like any other app.

The app operates in the `/share/owntone` folder: `dbase_and_logs/` holds the database, config and logs; `music/` is where your music and playlists go. The AirPlay pipes also live in `music/` so OwnTone's library watcher sees them.

## Configuration

Each configuration key is documented inline in the add-on's **Configuration** tab in Home Assistant (the descriptions come from `translations/en.yaml`, keyed under `configuration.<group>.fields.<key>`).

Available option groups (see `config.yml` for defaults and the full schema):

- `general` — admin password, log level, trusted networks
- `library` — library name/password and iTunes/m3u metadata overrides
- `airplay` / `chromecast` — per-device settings (name, max volume, exclude, nickname, …)
- `shairport` — built-in shairport-sync AirPlay receiver (advertised name, metadata)

### Examples
#### HomePod
Disable Airplay 1 for an HomePod. The name needs to be the exact name of your Homepod.
```
airplay: 
  - name: "HomePod"
    raop_disable: true
```
## Considerations

### AirPlay 2
OwnTone supports AirPlay 2 but only to devices that don't request a password. To make HomePods work with it, open the Home app on your iPhone/iPad → home icon (top left) → **Home Settings → Allow access** → set it to **All in the same network**.

### Networking
This app runs with `host_network: true`. AirPlay/mDNS discovery is multicast and does not cross the Docker bridge NAT, so in bridge mode the shairport-sync receiver would be invisible to phones on the LAN. With host networking, all ports (3689 web/API, 3688 websocket, 6600 MPD, 3690/3691 AirPlay, 5000 + 6001–6003 shairport-sync) bind directly on the host.

### Volume behavior
With the default `shairport.metadata_enabled: false`, the AirPlay source's volume is ignored — audio always passes through at 100% and room volume is controlled per output in OwnTone. Enabling metadata gives you now-playing info (title/artist/cover) but also lets the source's volume control OwnTone's master volume.

## Credits
Originally inspired by https://github.com/Ulrar/hassio-addons/tree/master/forked-daapd and forked from https://github.com/mynameisdaniel32/hassio-addon-owntone-latest.

## License

MIT

**Free Software, Hell Yeah!**
