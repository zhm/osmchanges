#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'
require 'mongo'
require 'thor'
require 'nokogiri'
require 'yaml'
require 'zlib'
require 'open-uri'
require 'active_support/all'

include Mongo

class OsmChanges < Thor
  desc "import", "Import changeset file for the first time"
  method_option :file, :aliases => "-f", :desc => "Input file", :required => true
  def import
    parse_changesets(File.open(options[:file])) do |changeset|
      if !changesets_collection.find_one(id: changeset['id'])
        changesets_collection.insert(changeset)
        puts "Creating changeset #{changeset['id']}"
      end
    end
  end

  desc "sync", "Sync changesets from planet.osm.org"
  method_option :sequence, :aliases => "-s", :desc => "Sequence number to start at", :required => false
  def sync
    current_state = state_collection.find.first

    raise "no sync state found. 'sequence' argument required for first sync" if options[:sequence].nil? and current_state.nil?

    local_state = options[:sequence] || current_state['sequence']

    server_state = YAML.load(`curl -s http://planet.openstreetmap.org/replication/changesets/state.yaml`)['sequence']

    (local_state.to_i .. server_state.to_i).each do |seq|
      sync_sequence(seq)
    end
  end

  desc "autosync", "Run the sync continuously"
  def autosync
    # this is mostly for testing/debugging
    while true
      puts `ruby osmchanges.rb sync`
      sleep(70)
    end
  end

  no_tasks do
    def mongo_client
      @client ||= MongoClient.new("localhost", 27017)
    end

    def mongo_database
      @db ||= mongo_client.db("osm_changesets")
    end

    def changesets_collection
      @changesets ||= mongo_database.collection("changesets")
    end

    def state_collection
      @state_collection ||= mongo_database.collection("state")
    end

    def sync_sequence(seq)
      puts "Processing sequence #{seq}"
      padded = "%09d" % seq.to_i

      source = open("http://planet.openstreetmap.org/replication/changesets/#{padded[0..2]}/#{padded[3..5]}/#{padded[6..8]}.osm.gz")

      parse_changesets(Zlib::GzipReader.new(source)) do |changeset|
        if !changesets_collection.find_one(id: changeset['id'])
          changesets_collection.insert(changeset)
        end
      end

      state = state_collection.find.first || {}
      state['sequence'] = seq.to_i
      state_collection.save(state)
    end

    def parse_changesets(xml)
      current_record = nil

      Nokogiri::XML::Reader(xml).each_with_index do |node, index|
        if node.name == 'changeset'
          if node.node_type == Nokogiri::XML::Reader::TYPE_ELEMENT
            current_record = node.attributes.merge(tags: {})
            current_record['id'] = current_record['id'].to_i
            current_record['uid'] = current_record['uid'].to_i
            current_record['num_changes'] = current_record['num_changes'].to_i
            current_record['open'] = current_record['open'] == 'false' ? false : true
            current_record['closed_at'] = Time.parse(current_record['closed_at']) if current_record['closed_at']
            current_record['created_at'] = Time.parse(current_record['created_at']) if current_record['created_at']
            current_record['min_lat'] = current_record['min_lat'].to_f
            current_record['min_lon'] = current_record['min_lon'].to_f
            current_record['max_lat'] = current_record['max_lat'].to_f
            current_record['max_lon'] = current_record['max_lon'].to_f
          end

          if node.node_type == Nokogiri::XML::Reader::TYPE_END_ELEMENT || node.self_closing?
            yield(current_record)
          end
        end

        if node.name == 'tag'
          current_record[:tags][node.attributes['k'].gsub('.', '-')] = node.attributes['v']
        end
      end
    end
  end
end

OsmChanges.start
