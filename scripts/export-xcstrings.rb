#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "json"
require "cgi"

if ARGV.length != 2
  warn "usage: export-xcstrings.rb INPUT.xcstrings OUTPUT_DIR"
  exit 1
end

input_path = File.expand_path(ARGV[0])
output_root = File.expand_path(ARGV[1])

catalog = JSON.parse(File.read(input_path))
strings = catalog.fetch("strings")
source_language = catalog.fetch("sourceLanguage", "en")

entries_by_locale = Hash.new { |hash, key| hash[key] = {} }
stringsdict_entries_by_locale = Hash.new { |hash, key| hash[key] = {} }

def build_stringsdict_entry(format_value, substitutions)
  return nil unless substitutions.is_a?(Hash) && !substitutions.empty?

  entry = { "NSStringLocalizedFormatKey" => format_value }

  substitutions.each do |name, substitution|
    plural_rules = substitution.dig("variations", "plural")
    next unless plural_rules.is_a?(Hash) && !plural_rules.empty?

    value_type = substitution["formatSpecifier"] || "d"
    substitution_entry = {
      "NSStringFormatSpecTypeKey" => "NSStringPluralRuleType",
      "NSStringFormatValueTypeKey" => value_type
    }

    plural_rules.each do |category, category_entry|
      category_value = category_entry.dig("stringUnit", "value")
      next unless category_value

      substitution_entry[category] = category_value
    end

    next if substitution_entry.length <= 2

    entry[name] = substitution_entry
  end

  return nil if entry.length == 1

  entry
end

strings.each do |key, entry|
  localizations = entry.fetch("localizations", {})
  next if localizations.empty?

  source_entry = localizations[source_language] || localizations.values.first
  default_value = source_entry&.dig("stringUnit", "value")
  default_substitutions = source_entry&.fetch("substitutions", nil)

  localizations.each do |locale, localized_entry|
    value = localized_entry.dig("stringUnit", "value") || default_value
    next unless value

    substitutions = localized_entry.fetch("substitutions", nil) || default_substitutions
    stringsdict_entry = build_stringsdict_entry(value, substitutions)

    if stringsdict_entry
      stringsdict_entries_by_locale[locale][key] = stringsdict_entry
    else
      entries_by_locale[locale][key] = value
    end
  end
end

def escape_strings_value(value)
  value
    .gsub("\\", "\\\\\\\\")
    .gsub("\"", "\\\\\"")
    .gsub("\n", "\\n")
end

def escape_plist_value(value)
  CGI.escapeHTML(value.to_s).gsub("'", "&apos;")
end

def write_plist_node(file, value, indent = 0)
  prefix = "  " * indent

  case value
  when Hash
    file.puts "#{prefix}<dict>"
    value.each do |key, nested_value|
      file.puts "#{prefix}  <key>#{escape_plist_value(key)}</key>"
      write_plist_node(file, nested_value, indent + 1)
    end
    file.puts "#{prefix}</dict>"
  else
    file.puts "#{prefix}<string>#{escape_plist_value(value)}</string>"
  end
end

FileUtils.mkdir_p(output_root)

locales = (entries_by_locale.keys + stringsdict_entries_by_locale.keys).uniq.sort

locales.each do |locale|
  locale_dir = File.join(output_root, "#{locale}.lproj")
  FileUtils.mkdir_p(locale_dir)

  entries = entries_by_locale[locale]
  unless entries.empty?
    strings_path = File.join(locale_dir, "Localizable.strings")
    File.open(strings_path, "w:utf-8") do |file|
      entries.sort_by { |key, _| key }.each do |key, value|
        file.puts "\"#{escape_strings_value(key)}\" = \"#{escape_strings_value(value)}\";"
      end
    end
  end

  stringsdict_entries = stringsdict_entries_by_locale[locale]
  unless stringsdict_entries.empty?
    stringsdict_path = File.join(locale_dir, "Localizable.stringsdict")
    File.open(stringsdict_path, "w:utf-8") do |file|
      file.puts %(<?xml version="1.0" encoding="UTF-8"?>)
      file.puts %(<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">)
      file.puts %(<plist version="1.0">)
      file.puts %(<dict>)
      stringsdict_entries.sort_by { |key, _| key }.each do |key, value|
        file.puts "  <key>#{escape_plist_value(key)}</key>"
        write_plist_node(file, value, 1)
      end
      file.puts %(</dict>)
      file.puts %(</plist>)
    end
  end
end
