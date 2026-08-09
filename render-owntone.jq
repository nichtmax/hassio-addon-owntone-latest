def config_value:
  if type == "string" then tojson
  elif type == "boolean" or type == "number" then tostring
  elif type == "array" then "{ " + (map(tojson) | join(", ")) + " }"
  else error("unsupported configuration value type: \(type)")
  end;

def fields($object; $skip):
  $object
  | to_entries
  | map(select(.value != null and (.key as $key | $skip | index($key) | not)))
  | map("\t\(.key) = \(.value | config_value)")
  | join("\n");

def section($name; $object):
  "\($name) {\n\(fields($object; []))\n}\n";

def named_sections($name; $items):
  ($items // [])
  | map(
      . as $item
      | ($item.name | tojson) as $section_name
      | fields($item; ["name", "raop_disable"]) as $body
      | $name + " " + $section_name + " {\n" + $body + "\n}\n"
    )
  | join("\n");

def airplay_sections($items):
  ($items // [])
  | map(
      . as $item
      | ($item + (if $item.airplay2_disable == null and $item.raop_disable != null
                  then {airplay2_disable: $item.raop_disable}
                  else {}
                  end)) as $normalized
      | ($normalized.name | tojson) as $section_name
      | fields($normalized; ["name", "raop_disable"]) as $body
      | "airplay " + $section_name + " {\n" + $body + "\n}\n"
    )
  | join("\n");

. as $root
| ($root.shairport.pipe_sample_rate // 44100 | tonumber) as $pipe_rate
| ($root.shairport.pipe_sample_format // "S16_LE") as $pipe_format
| (if $pipe_format == "S32_LE" then 32 else 16 end) as $pipe_bits
| (($root.general // {}) + {
    uid: "owntone",
    db_path: "/share/owntone/dbase_and_logs/songs3.db",
    db_backup_path: "/share/owntone/dbase_and_logs/songs3.bak",
    logfile: "/share/owntone/dbase_and_logs/owntone.log",
    websocket_port: 3688,
    cache_dir: "/share/owntone/dbase_and_logs"
  }) as $general
| (($root.library // {}) + {
    port: 3689,
    directories: ["/share/owntone/music"],
    pipe_autostart: true,
    pipe_sample_rate: $pipe_rate,
    pipe_bits_per_sample: $pipe_bits
  }) as $library
| (($root.audio // {}) + (if ($root.audio.type // null) == null then {type: "dummy"} else {} end)) as $audio
| (($root.airplay_shared // {}) + {control_port: 3690, timing_port: 3691}) as $airplay_shared
| (($root.mpd // {}) + {port: 6600, http_port: 0}) as $mpd
| (($root.streaming // {})
   | if .bit_rate != null then .bit_rate |= tonumber else . end) as $streaming
| section("general"; $general)
  + "\n" + section("library"; $library)
  + "\n" + section("audio"; $audio)
  + (if (($root.alsa // []) | length) > 0 then "\n" + named_sections("alsa"; $root.alsa) else "" end)
  + (if (($root.fifo // {}) | length) > 0 then "\n" + section("fifo"; $root.fifo) else "" end)
  + "\n" + section("airplay_shared"; $airplay_shared)
  + (if (($root.airplay // []) | length) > 0 then "\n" + airplay_sections($root.airplay) else "" end)
  + (if (($root.chromecast // []) | length) > 0 then "\n" + named_sections("chromecast"; $root.chromecast) else "" end)
  + "\n" + section("spotify"; ($root.spotify // {}))
  + (if (($root.rcp // []) | length) > 0 then "\n" + named_sections("rcp"; $root.rcp) else "" end)
  + "\n" + section("mpd"; $mpd)
  + "\n" + section("sqlite"; ($root.sqlite // {}))
  + "\n" + section("streaming"; $streaming)
