#!/usr/bin/env ruby
require "yaml"

root = File.expand_path("..", __dir__)
config = YAML.safe_load_file(File.join(root, "config.yaml"), aliases: false)
translations = YAML.safe_load_file(File.join(root, "translations/en.yaml"), aliases: false)

def schema_fields(schema)
  schema.flat_map do |group, value|
    fields = value.is_a?(Array) ? value.first : value
    next [] unless fields.is_a?(Hash)
    fields.keys.map { |field| "#{group}.#{field}" }
  end.sort
end

schema = schema_fields(config.fetch("schema"))
translated = translations.fetch("configuration").flat_map do |group, data|
  (data["fields"] || {}).keys.map { |field| "#{group}.#{field}" }
end.sort

missing_translations = schema - translated
extra_translations = translated - schema
abort "Missing translations: #{missing_translations.join(', ')}" unless missing_translations.empty?
abort "Translations without schema fields: #{extra_translations.join(', ')}" unless extra_translations.empty?

catalog = File.readlines(File.join(__dir__, "owntone-option-catalog.txt"), chomp: true)
catalog.reject! { |line| line.empty? || line.start_with?("#") }
missing_catalog = catalog - schema
abort "Upstream catalog fields missing from schema: #{missing_catalog.join(', ')}" unless missing_catalog.empty?

required_shairport = %w[
  shairport.name
  shairport.password
  shairport.metadata_enabled
  shairport.ignore_volume_control
  shairport.pipe_sample_rate
  shairport.pipe_sample_format
]
missing_shairport = required_shairport - schema
abort "Shairport pipe fields missing from schema: #{missing_shairport.join(', ')}" unless missing_shairport.empty?

puts "Schema audit passed: #{schema.length} fields, all translated"
