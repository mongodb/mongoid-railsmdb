# frozen_string_literal: true

require 'railsmdb/version'
require 'railsmdb/crypt_shared/catalog'
require 'railsmdb/downloader'
require 'railsmdb/extractor'
require 'railsmdb/prioritizable'
require 'rails/generators/rails/app/app_generator'
require 'mongoid'

module Rails
  module Generators
    # Monkeypatch the Rails AppGenerator class to make it emit a Mongoid-friendly
    # application.
    #
    # @api private
    class AppGenerator
      include Railsmdb::Prioritizable

      # add the Railsmdb templates folder to the source path
      source_paths.unshift File.join(__dir__, 'templates')

      # An option for enabling MongoDB encryption features in the new app.
      class_option :encryption, type: :boolean,
                                aliases: '-E',
                                default: false,
                                desc: 'Add gems and configuration to enable MongoDB encryption features'

      # Add an option for accepting the customer agreement related to
      # MongoDB enterprise, allowing the acceptance prompt to be skipped.
      class_option :accept_customer_agreement, type: :boolean,
                                               default: false,
                                               desc: 'Accept the MongoDB Customer Agreement'

      # change the --skip-active-record option to default to true. Users
      # may pass --no-skip-active-record to enable it again, if they want
      # to use both Mongoid and ActiveRecord.
      class_option :skip_active_record, type: :boolean,
                                        aliases: '-O',
                                        default: true,
                                        desc: 'Skip Active Record files'

      prioritize :confirm_legal_shenanigans, :before, :create_root
      prioritize :fetch_crypt_shared, :after, :create_root

      # Checks to see if the user agrees to the encryption terms and conditions
      def confirm_legal_shenanigans
        return unless options[:encryption]

        @okay_to_support_encryption =
          options[:accept_customer_agreement] ||
          okay_with_legal_shenanigans?
      end

      # Fetches the MongoDB crypt_shared library and stores it in
      # vendor/crypt_shared.
      def fetch_crypt_shared
        return unless @okay_to_support_encryption

        log :fetch, 'current MongoDB catalog'
        catalog = Railsmdb::CryptShared::Catalog.current
        url = catalog.optimal_download_url_for_this_host

        if url
          fetch_and_extract_crypt_shared_from_url(url)
        else
          say_error 'Cannot find download URL for crypt_shared, for this host'
        end
      end

      # Emit the mongoid.yml file to the new application folder. The
      # mongoid.yml file is taken directly from the installed mongoid
      # gem.
      def mongoid_yml
        file = Gem.find_files('rails/generators/mongoid/config/templates/mongoid.yml').first
        database_name = app_name
        template file, 'config/mongoid.yml', context: binding
      end

      # Emit the mongoid.rb initializer. Unlike mongoid.yml, this is not
      # taken from the mongoid gem, because mongoid versions prior to 9
      # did not include an initializer template.
      def mongoid_initializer
        template '_config/initializers/mongoid.rb', 'config/initializers/mongoid.rb'
      end

      # Emit the bin/railsmdb script to the new app's bin folder. The
      # existing bin/rails script is removed, and replaced by a link to
      # bin/railsmdb.
      def railsmdb
        template '_bin/railsmdb', 'bin/railsmdb' do |content|
          "#{shebang}\n" + content
        end

        chmod 'bin/railsmdb', 0o755, verbose: false

        remove_file 'bin/rails', verbose: false
        create_link 'bin/rails', File.expand_path('bin/railsmdb', destination_root), verbose: false
      end

      # OVERRIDES
      # The following methods override the existing methods on AppGenerator,
      # to replace the default behavior with Mongoid-specific behavior.

      # Overridden to ignore the "skip_active_record" guard. We always want the
      # db folder, even when active record is being skipped.
      def create_db_files
        build(:db)
      end

      # Overridden to save the current directory; this way, we can see
      # if it is being run from the railsmdb project directory, in
      # development, and set up the railsmdb gem dependency appropriately.
      def create_root
        @initial_path = Dir.pwd
        super
      end

      # Overridden to append the mongoid gem entries to the Gemfile.
      def run_bundle
        add_mongoid_gem_entries
        super
      end

      private

      # Returns the Railsmdb project directory if run from inside a
      # checkout of the railsmdb repository. Otherwise, returns nil.
      #
      # @return [ String | nil ] the railsmdb project directory, or nil
      #   if not run within a railsmdb checkout.
      def railsmdb_project_directory
        return @railsmdb_project_directory if defined?(@railsmdb_project_directory)

        @railsmdb_project_directory ||= begin
          path = @initial_path

          while path != '.'
            break if File.exist?(File.join(path, 'railsmdb.gemspec'))

            path = File.dirname(path)
          end

          (path == '.') ? nil : path
        end
      end

      # Appends the mongoid gem entries to the Gemfile.
      def add_mongoid_gem_entries
        mongoid_gem_entries.each do |group, list|
          append_to_file 'Gemfile' do
            prefix = group ? "\ngroup :#{group} do\n" : "\n"
            suffix = group ? "\nend\n" : "\n"
            indent_size = group ? 2 : 0

            prefix +
              list.map { |entry| indent_entry(entry, indent_size) }
                  .join("\n\n") +
              suffix
          end
        end
      end

      # Adds indentation to the string representation of the given
      # gem entry.
      #
      # @param [ Rails::Generators::AppBase::GemfileEntry ] entry The
      #   GemfileEntry instance to format.
      # @param [ Integer ] indent_size the number of spaces to prepend
      #   to each line of the entry's string representation.
      #
      # @return [ String ] the string representation of the given entry
      #   with each line indented by the given number of spaces.
      def indent_entry(entry, indent_size)
        if indent_size < 1
          entry.to_s
        else
          indent = ' ' * indent_size
          entry.to_s.gsub(/^/, indent)
        end
      end

      # The gem entries to be appended to the Gemfile, sorted by gem
      # group.
      #
      # @return [ Hash ] a hash where the keys are the gem groups, and
      #   the values are lists of gem entries corresponding to those
      #   groups.
      def mongoid_gem_entries
        {
          nil => [
            mongoid_gem_entry,
            railsmdb_gem_entry
          ].tap { |list| maybe_add_encryption_gems(list) }
        }
      end

      # The gem entry for the Mongoid gem. The version is set to whichever
      # version is installed and active.
      #
      # @return [ Rails::Generators::AppBase::GemfileEntry ] the gem
      #   entry for Mongoid.
      def mongoid_gem_entry
        GemfileEntry.version \
          'mongoid',
          ::Mongoid::VERSION,
          'Use MongoDB for the database, with Mongoid as the ODM'
      end

      # The gem entry for the Railsmdb gem. If run from a railsmdb
      # checkout, the gem will reference the path to that checkout.
      # Otherwise, the version is set to whichever
      # version is installed and active.
      #
      # @return [ Rails::Generators::AppBase::GemfileEntry ] the gem
      #   entry for Railsmdb.
      def railsmdb_gem_entry
        if railsmdb_project_directory.present?
          GemfileEntry.path \
            'mongoid-railsmdb',
            railsmdb_project_directory,
            'The development version of railsmdb'
        else
          GemfileEntry.version \
            'mongoid-railsmdb',
            Railsmdb::Version::STRING,
            'The Rails CLI tool for MongoDB'
        end
      end

      # Build the gem entry for the libmongocrypt-helper gem.
      #
      # @return [ Rails::Generators::AppBase::GemfileEntry ] the gem
      #   entry for libmongocrypt-helper gem.
      def libmongocrypt_helper_gem_entry
        GemfileEntry.version \
          'libmongocrypt-helper', '~> 1.8',
          'Encryption helper for MongoDB-based applications'
      end

      # If encryption is enabled, adds the necessary gems to the given list
      # of gem entries, to prepare them to be added to the gemfile.
      #
      # @param [ Array<GemfileEntry> ] list The list of gemfile entries.
      def maybe_add_encryption_gems(list)
        return unless @okay_to_support_encryption

        list.push libmongocrypt_helper_gem_entry
      end

      # The location of the directory where the crypt_shared library will
      # be saved to, relative to the app root.
      CRYPT_SHARED_DIR = 'vendor/crypt_shared'

      # Download and extract the crypt_shared library from the given url,
      # and install it in vendor/crypt_shared.
      #
      # @param [ String ] url the url to the crypt_shared library archive
      def fetch_and_extract_crypt_shared_from_url(url)
        archive = fetch_crypt_shared_from_url(url)

        log :directory, CRYPT_SHARED_DIR
        FileUtils.mkdir_p CRYPT_SHARED_DIR

        extracted = extract_crypt_shared_from_file(archive)

        log :error, 'No crypt_shared library could be found in the downloaded archive' unless extracted
      end

      # Download the crypt_shared library archive from the given url and
      # store it in the current directory.
      #
      # @param [ String ] url the url to fetch the file from
      #
      # @return [ String ] the filename that the archive was saved to
      def fetch_crypt_shared_from_url(url)
        log :fetch, url

        uri = URI.parse(url)
        File.basename(uri.path).tap do |archive|
          Railsmdb::Downloader.fetch(url, archive) { print '.' }
          puts
        end
      end

      # Extracts the crypt_shared library from the given archive file, and
      # writes it to the CRYPT_SHARED_DIR.
      #
      # @param [ String ] archive the path to the archive file
      #
      # @return [ String | nil ] the name of the extracted file if successful,
      #   or nil if no file could be extracted.
      def extract_crypt_shared_from_file(archive)
        extractor = Railsmdb::Extractor.for(archive)
        extractor.extract(%r{/mongo_crypt_v1\.(so|dylib|dll)}) do |name, data|
          file = File.join(CRYPT_SHARED_DIR, File.basename(name))

          log :create, file
          File.open(file, 'w:BINARY') { |io| io.write(data) }
        end
      end

      # Ask the user if they agree to the MongoDB Customer Agreement, which is
      # required in order to download the crypt_shared library.
      #
      # @return [ true | false ] whether the user agrees or not
      def okay_with_legal_shenanigans?
        # primarily so we can interact with this programmatically in tests...
        $stdout.sync = true

        say "You've requested to begin a new Rails app with MongoDB encryption."
        say

        say "Using MongoDB's encryption features requires MongoDB Enterprise Edition,"
        say 'which is for MongoDB customers only. Are you a MongoDB Atlas customer, or'
        say 'are you currently a MongoDB Enterprise Advanced subscriber?'
        say

        case ask('"[yes], I am a MongoDB customer", or "[no], I am not" =>', limited_to: %w[ yes no ])
        when 'yes'
          say
          say '* Use of these features constitutes acceptance of the Customer Agreement.'
          say

          true
        when 'no'
          say
          say '* Encryption will not be enabled for your application.'
          say

          false
        end
      end
    end
  end
end
