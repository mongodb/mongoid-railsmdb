# frozen_string_literal: true

require 'railsmdb/crypt_shared/listing'
require 'os'

module Railsmdb
  module CryptShared
    # A utility method for querying a catalog listing.
    #
    # @api private
    class Catalog
      class << self
        # Return a Catalog instance representing the current listing.
        #
        # @return [ Catalog ] the current listing.
        def current
          new(Listing.fetch)
        end
      end

      # @return [ Hash ] the current listing
      attr_reader :listing

      # Create a new Catalog instance from the giving listing.
      #
      # @param [ Hash ] listing the data to query
      def initialize(listing)
        @listing = listing
      end

      # Queries the listing data using the given criteria, yielding the
      # corresponding download data.
      #
      # @example Finding all production releases for M1 macs
      #   catalog.downloads(
      #     production_release: true,
      #     downloads: { arch: 'arm64', target: 'macos' }
      #   ) do |download|
      #     puts download['crypt_shared']['url']
      #   end
      #
      # @param [ Hash ] criteria the criteria hash
      #
      # @yield [ Hash ] each download record matching the criteria
      def downloads(criteria = {})
        download_criteria = criteria.delete(:downloads) || {}

        listing['versions'].each do |version|
          next unless hash_matches?(version, criteria)

          version['downloads'].each do |download|
            next unless hash_matches?(download, download_criteria)

            yield download
          end
        end

        self
      end

      # Queries the listing for all downloads that match the platform
      # criteria for the current host.
      #
      # @param [ String ] which the download entry to return
      #
      # @return [ Array<String, String> ] a tuple of (url, sha256) for the
      #    requested download.
      def optimal_download_url_for_this_host(which = 'crypt_shared')
        downloads(production_release: true, downloads: download_criteria) do |dl|
          return [ dl[which]['url'], dl[which]['sha256'] ]
        end

        nil
      end

      # Returns the download criteria (arch/target/edition) for the current
      # host.
      #
      # @return [ Hash ] the download criteria
      def download_criteria
        {
          arch: platform_arch,
          target: platform_target,
          edition: 'enterprise'
        }
      end

      private

      # @return [ String ] the host CPU specification.
      def platform_arch
        OS.host_cpu
      end

      # @return [ String ] the normalized host operating system
      def platform_target
        if OS.windows? || OS::Underlying.windows?
          'windows'
        elsif OS.mac?
          'macos'
        elsif OS.linux?
          # this will almost certainly need tweaking
          release = OS.parse_os_release
          id = release[:ID]
          version = release[:VERSION_ID].gsub(/[^\d]/, '')
          "#{id}#{version}"
        else
          warn 'cannot install the crypt_shared library for this platform'
        end
      end

      # Asks if the given hash satisfies all the given criteria.
      #
      # @param [ Hash ] hash the hash to query
      # @param [ Hash ] criteria the criteria to use for the query
      #
      # @return [ true | false ] whether the hash meets the criteria or not.
      def hash_matches?(hash, criteria)
        criteria.all? { |key, value| hash[key.to_s] == value }
      end
    end
  end
end
