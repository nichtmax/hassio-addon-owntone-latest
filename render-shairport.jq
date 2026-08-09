def q: tojson;

.shairport as $s
| ($s.name // "Multiroom") as $name
| ($s.password // "") as $password
| ($s.metadata_enabled // false) as $metadata
| (if $s.ignore_volume_control == null then true else $s.ignore_volume_control end) as $ignore_volume
| ($s.pipe_sample_rate // 44100 | tonumber) as $pipe_rate
| ($s.pipe_sample_format // "S16_LE") as $pipe_format
| (if $ignore_volume then "yes" else "no" end) as $ignore_text
| "general = {\n"
  + "  name = \($name | q);\n"
  + (if $password == "" then "" else "  password = \($password | q);\n" end)
  + "  output_backend = \("pipe" | q);\n"
  + "  mdns_backend = \("avahi" | q);\n"
  + "  ignore_volume_control = \($ignore_text | q);\n"
  + "  volume_max_db = 0.0;\n"
  + "};\n\n"
  + (if $metadata then
       "metadata = {\n"
       + "  enabled = \("yes" | q);\n"
       + "  include_cover_art = \("yes" | q);\n"
       + "  pipe_name = \("/share/owntone/music/AirPlay.metadata" | q);\n"
       + "};\n\n"
     else "" end)
  + "pipe = {\n"
  + "  name = \("/share/owntone/music/AirPlay" | q);\n"
  + "  output_rate = \($pipe_rate);\n"
  + "  output_format = \($pipe_format | q);\n"
  + "  output_channels = 2;\n"
  + "};\n"
