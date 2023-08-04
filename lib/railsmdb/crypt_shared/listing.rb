# frozen_string_literal: true

require 'json'
require 'open-uri'
require 'tmpdir'

module Railsmdb
  module CryptShared
    # A utility class for fetching the JSON list of current MongoDB
    # database offerings.
    #
    # @api private
    class Listing
      # Convenience method for fetching and returning the current listing.
      #
      # @return [ Hash ] the parsed JSON contents of the listing
      def self.fetch
        new.listing
      end

      # Downloads and parses the listing, returning the result.
      #
      # @return [ Hash ] the parsed JSON contents of the listing
      def listing
        @listing ||= fetch_listing_json
      end

      private

      # the URI of the current.json catalog
      CURRENT_URI = 'https://downloads.mongodb.org/current.json'

      # where the JSON file should be cached
      CURRENT_CACHE = File.join(Dir.tmpdir, '.current.json')

      # how old the cache may be before it must be fetched again
      CACHE_CUTOFF = 24 * 60 * 60 # seconds in 24 hours

      # Fetches and parses the current catalog file, first checking the
      # cache, and then if necessary fetching from the remote server.
      #
      # @return [ Hash ] the parsed JSON catalog file
      def fetch_listing_json
        fetch_listing_json_from_cache ||
          fetch_listing_json_from_uri
      end

      # Looks at the cache for the requested catalog file. If it doesn't
      # exist, or if it is too old, this returns nil.
      #
      # @return [ Hash | nil ] the parsed JSON catalog file, or nil if
      #    it needs to be fetched from the server
      def fetch_listing_json_from_cache
        return nil unless File.exist?(CURRENT_CACHE)
        return nil unless File.mtime(CURRENT_CACHE) >= Time.now - CACHE_CUTOFF

        JSON.load_file(CURRENT_CACHE)
      end

      # Fetches the requested catalog file from the server. This will
      # save the fetched file to the cache.
      #
      # @return [ Hash ] the parsed JSON catalog file
      def fetch_listing_json_from_uri
        uri = URI.parse(CURRENT_URI)
        File.write(CURRENT_CACHE, uri.read)
        fetch_listing_json_from_cache
      end
    end
  end
end
