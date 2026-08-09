#!/usr/bin/env ruby
require "yaml"

abort "Usage: audit-upstream.rb /path/to/owntone.conf.in" unless ARGV.length == 1

root = File.expand_path("..", __dir__)
template = ARGV.fetch(0)
sections = %w[
  general library audio alsa fifo airplay_shared airplay chromecast spotify rcp
  mpd sqlite streaming
]

upstream = []
section = nil
File.foreach(template) do |line|
  if (match = line.match(/^#?\s*(#{sections.join('|')})(?:\s+"[^"]*")?\s*\{/))
    section = match[1]
  elsif line.match?(/^#?\s*\}/)
    section = nil
  elsif section && (match = line.match(/^#?\s*([a-zA-Z0-9_]+)\s*=/))
    upstream << "#{section}.#{match[1]}"
  end
end
upstream = upstream.uniq.sort

config = YAML.safe_load_file(File.join(root, "config.yaml"), aliases: false)
schema = config.fetch("schema").flat_map do |group, value|
  fields = value.is_a?(Array) ? value.first : value
  next [] unless fields.is_a?(Hash)
  fields.keys.map { |field| "#{group}.#{field}" }
end

owned = File.readlines(File.join(__dir__, "owntone-app-owned-options.txt"), chomp: true)
owned.reject! { |line| line.empty? || line.start_with?("#") }

missing = upstream - schema - owned
abort "Unclassified upstream settings: #{missing.join(', ')}" unless missing.empty?

exposed_owned = schema & owned
abort "App-owned settings exposed in schema: #{exposed_owned.join(', ')}" unless exposed_owned.empty?

stale_owned = owned - upstream
abort "App-owned catalog settings absent upstream: #{stale_owned.join(', ')}" unless stale_owned.empty?

puts "Upstream parity audit passed: #{upstream.length} template settings classified"
