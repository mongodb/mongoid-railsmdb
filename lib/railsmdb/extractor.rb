# frozen_string_literal: true

require 'minitar'
require 'zlib'
require 'zip'

module Railsmdb
  # A utility class for extracting a specific file from a given archive.
  # Currently only supports .tgz, .tar.gz, and .zip archives.
  class Extractor
    # Returns the appropriate extractor class for the given archive path.
    #
    # @param [ String ] archive_path the path to the archive file
    #
    # @return [ ZipExtractor | TarGzipExtractor ] the extractor instance
    #   corresponding to the given archive.
    def self.for(archive_path)
      case archive_path
      when /\.(tgz|tar\.gz)$/ then TarGzipExtractor.new(archive_path)
      when /\.zip$/ then ZipExtractor.new(archive_path)
      else raise ArgumentError, "don't know how to extract #{archive_path}"
      end
    end

    # The path to the archive.
    attr_reader :archive_path

    # Instantiates a new extractor with the given archive path.
    #
    # @param [ String ] archive_path the path to the archive.
    def initialize(archive_path)
      @archive_path = archive_path
    end

    # Extract the first file that matches the given pattern from the
    # archive.
    #
    # @param [ Regexp ] pattern the pattern to use for finding the file
    #
    # @yield [ String, String ] report the name and contents of the first
    #   matching file. It will never yield more than once.
    #
    # @return [ String | nil ] returns the name of the matching file, or
    #   nil if no file matched.
    #
    # @raise [ NotImplementedError ] subclasses must override this method.
    def extract(pattern)
      raise NotImplementedError
    end
  end

  # An extractor subclass for dealing with .zip files.
  #
  # @api private
  class ZipExtractor < Extractor
    # See Extractor#extract for documentation.
    def extract(pattern)
      Zip::File.open(archive_path).each do |entry|
        if entry.name.match?(pattern)
          yield entry.name, entry.get_input_stream.read.force_encoding('BINARY')
          return entry.name
        end
      end

      nil
    end
  end

  # An extractor subclass for dealing with .tgz/.tar.gz files.
  #
  # @api private
  class TarGzipExtractor < Extractor
    # See Extractor#extract for documentation.
    def extract(pattern)
      reader.each_entry do |entry|
        if entry.name.match?(pattern)
          yield entry.name, entry.read.force_encoding('BINARY')
          return entry.name
        end
      end

      nil
    end

    # Returns a reader able to iterate over all the entries in the
    # archive.
    def reader
      @reader ||= begin
        gzip = Zlib::GzipReader.new(File.open(archive_path, 'rb'))
        Minitar::Reader.new(gzip)
      end
    end
  end
end
