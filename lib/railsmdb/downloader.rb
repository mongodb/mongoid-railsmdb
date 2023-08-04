# frozen_string_literal: true

require 'faraday'

module Railsmdb
  # A utility class for downloading a file from a given URL.
  class Downloader
    # @return [ String ] the url to download from
    attr_reader :url

    # @return [ String ] where the file should be saved to.
    attr_reader :destination

    # A helper method for fetching the file in a single call.
    #
    # @param [ String ] url the url to fetch from
    # @param [ String ] destination the location to write to
    # @param [ Proc ] callback a callback block that is invoked with the
    #   current total number of bytes read, as each chunk is read from the
    #   stream.
    def self.fetch(url, destination, &callback)
      new(url, destination).fetch(&callback)
    end

    # Create a new Downloader object.
    #
    # @param [ String ] url the url to fetch from
    # @param [ String ] destination the location to write to
    def initialize(url, destination)
      @url = url
      @destination = destination
    end

    # Perform the fetch, pulling from the url and writing to the destination.
    def fetch
      File.open(destination, 'w:BINARY') do |io|
        connection.get(url) do |req|
          req.options.on_data = lambda do |chunk, total, _env|
            yield total if block_given?
            io << chunk
          end
        end
      end

      true
    end

    private

    # The underlying HTTP connection used to query the file.
    def connection
      @connection ||= Faraday.new(url: url, ssl: { verify: false, verify_hostname: false })
    end
  end
end
