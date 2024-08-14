# frozen_string_literal: true

# Helper methods for use by the template.rb file. This should be referenced
# via `load`, and not `require`, so that it is loaded into the context of an
# existing task.

require 'mongoid'
require 'railsmdb/version'

require 'railsmdb/crypt_shared/catalog'
require 'railsmdb/downloader'
require 'railsmdb/extractor'

module Railsmdb
  # Helper tasks and utilities related to preparing a new Rails app
  # for use with Mongoid.
  module Helpers
    # The location of the directory where the crypt_shared library will
    # be saved to, relative to the app root.
    CRYPT_SHARED_DIR = 'vendor/crypt_shared'

    # The location of the encrypted credentials file
    CREDENTIALS_FILE_PATH = 'config/credentials.yml.enc'

    KEY_VAULT_CONFIG = <<~CONFIG
    # This client is used to obtain the encryption keys from the key vault.
    # For security reasons, this should be a different database instance than
    # your primary application database.
    key_vault:
      uri: mongodb://localhost:27017

    CONFIG

    AUTO_ENCRYPTION_CONFIG = <<~CONFIG.freeze
    # You can read about the auto encryption options here:
    # https://www.mongodb.com/docs/ruby-driver/v#{Mongo::VERSION.split('.').first(2).join('.')}/reference/in-use-encryption/client-side-encryption/#auto-encryption-options
    auto_encryption_options:
      key_vault_client: 'key_vault'
      key_vault_namespace: 'encryption.__keyVault'
      kms_providers:
        # Using a local master key is insecure and is not recommended if you plan
        # to use client-side encryption in production.
        #
        # To learn how to set up a remote Key Management Service, see the tutorials
        # at https://www.mongodb.com/docs/manual/core/csfle/tutorials/.
        local:
          key: '<%= Rails.application.credentials.mongodb_master_key %>'
      extra_options:
        crypt_shared_lib_path: %crypt-shared-path%

    CONFIG

    PRELOAD_MODELS_OPTION = <<~CONFIG
    #
    # Setting it to true is recommended for auto encryption to work
    # properly in development.
    preload_models: true
    CONFIG

    # Declare the mongoid gem as a dependency.
    def mongoid_gem
      gem 'mongoid', Mongoid::VERSION, comment: 'Use MongoDB for the database, with Mongoid as the ODM'
    end

    # Declare the railsmdb gem as a dependency.
    def railsmdb_gem
      # mostly for testing; lets us specify the path to the railsmdb instance
      # that is under test.
      if ENV['RAILSMDB_PATH']
        gem 'railsmdb', path: ENV['RAILSMDB_PATH'], comment: 'The Rails CLI tool for Mongoid'
      else
        gem 'railsmdb', Railsmdb::Version::STRING, comment: 'The Rails CLI tool for Mongoid'
      end
    end

    # Check the CLI options, and possibly prompt the user, to see whether
    # encryption support is desired, and whether they agree to the customer
    # agreement.
    def confirm_legal_shenanigans
      @okay_to_support_encryption =
        options[:encryption] &&
        options.fetch(:accept_customer_agreement) { okay_with_legal_shenanigans? }
    end

    def possibly_support_encryption
      return unless @okay_to_support_encryption

      gem 'libmongocrypt-helper', '~> 1.8', comment: 'Encryption helper for MongoDB-based applications'
      gem 'ffi', nil, comment: 'Mongoid needs the ffi gem when encryption is enabled'

      log :fetch, 'current MongoDB catalog'
      catalog = Railsmdb::CryptShared::Catalog.current
      url, sha = catalog.optimal_download_url_for_this_host

      if url
        fetch_and_extract_crypt_shared_from_url(url, sha)
      else
        say_error 'Cannot find download URL for crypt_shared, for this host'
      end

      add_mongodb_local_master_key_to_credentials
    end

    # Download and extract the crypt_shared library from the given url,
    # and install it in vendor/crypt_shared.
    #
    # @param [ String ] url the url to the crypt_shared library archive
    # @param [ String ] sha the sha hash for the file
    def fetch_and_extract_crypt_shared_from_url(url, sha)
      archive = fetch_crypt_shared_from_cache(url, sha) ||
                fetch_crypt_shared_from_url(url, sha)

      return unless archive

      log :directory, CRYPT_SHARED_DIR
      FileUtils.mkdir_p CRYPT_SHARED_DIR

      extracted = extract_crypt_shared_from_file(archive)

      log :error, 'No crypt_shared library could be found in the downloaded archive' unless extracted
    end

    # Computes the path to the cache for the file at the given URL.
    #
    # @param [ String ] url the url to consider
    #
    # @return [ String ] the path to the file's location on disk.
    def cached_file_for(url)
      uri = URI.parse(url)
      File.join(Dir.tmpdir, File.basename(uri.path))
    end

    # Look in the cache location for a file downloaded from the given
    # url. If it exists, make sure the SHA hash matches.
    #
    # @param [ String ] url the url to fetch the file from
    # @param [ String ] sha the sha256 hash for the file
    #
    # @return [ String | nil ] the path to the file, if it exists, or nil
    def fetch_crypt_shared_from_cache(url, sha)
      path = cached_file_for(url)

      return path if File.exist?(path) && Digest::SHA256.file(path).to_s == sha

      nil
    end

    # Download the crypt_shared library archive from the given url and
    # store it in the current directory.
    #
    # @param [ String ] url the url to fetch the file from
    # @param [ String ] sha the sha256 hash for the file
    #
    # @return [ String ] the filename that the archive was saved to
    def fetch_crypt_shared_from_url(url, sha)
      log :fetch, url

      cached_file_for(url).tap do |archive|
        Railsmdb::Downloader.fetch(url, archive) { print '.' }
        puts

        unless File.exist?(archive) && Digest::SHA256.file(archive).to_s == sha
          log :error, 'an uncorrupted crypt-shared library could not be downloaded'
          return nil
        end
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

    # Appends a new local master key to the credentials file
    def add_mongodb_local_master_key_to_credentials
      say_status :append, CREDENTIALS_FILE_PATH

      credentials_file.change do |tmp_path|
        File.open(tmp_path, 'a') do |io|
          io.puts
          io.puts '# Master key for MongoDB auto encryption'
          # passing `96 / 2` because we need a 96-byte key, but
          # SecureRandom.hex returns a hex-encoded string, which will
          # be two bytes for requested byte.
          io.puts "mongodb_master_key: '#{SecureRandom.hex(96 / 2)}'"
        end
      end
    end

    # Grab the mongoid.yml template from the mongoid gem and apply it here.
    #
    # @note: it would be ideal to move this template from Mongoid to railsmdb,
    # but there is a lot of existing documentation around using the Mongoid
    # generators, and we'll need to tread carefully.
    def emit_mongoid_yml
      file = Gem.find_files('rails/generators/mongoid/config/templates/mongoid.yml').first
      database_name = app_name
      template file, 'config/mongoid.yml', context: binding
    end

    # If encryption is enabled, update the mongoid.yml with the necessary
    # options for encryption.
    def add_encryption_options_to_mongoid_yml
      return unless @okay_to_support_encryption

      mongoid_yml = File.join(Dir.pwd, 'config/mongoid.yml')
      contents = File.read(mongoid_yml)

      contents = insert_key_vault_config(contents)
      contents = insert_auto_encryption_options(contents)
      contents = insert_preload_models_option(contents)

      say_status :update, 'config/mongoid.yml'
      File.write(mongoid_yml, contents)
    end

    # Emit the mongoid.rb initializer. Unlike mongoid.yml, this is not
    # taken from the mongoid gem, because mongoid versions prior to 9
    # did not include an initializer template.
    def emit_mongoid_initializer
      template '_config/initializers/mongoid.rb', 'config/initializers/mongoid.rb'
    end

    # Emit the bin/railsmdb script to the new app's bin folder. The
    # existing bin/rails script is removed, and replaced by a link to
    # bin/railsmdb.
    def emit_railsmdb
      template '_bin/railsmdb', 'bin/railsmdb' do |content|
        "#{shebang}\n" + content
      end

      chmod 'bin/railsmdb', 0o755, verbose: false

      remove_file 'bin/rails', verbose: false
      create_link 'bin/rails', File.expand_path('bin/railsmdb', destination_root), verbose: false
    end

    # Return the encrypted credentials file.
    #
    # @return [ ActiveSupport::EncryptedConfiguration ] the encrypted
    #    credentials file.
    def credentials_file
      ActiveSupport::EncryptedConfiguration.new(
        config_path: CREDENTIALS_FILE_PATH,
        key_path: 'config/master.key',
        env_key: 'RAILS_MASTER_KEY',
        raise_if_missing_key: true
      )
    end

    # Attempts to insert the key-vault configuration into the given
    # string, which must be the contents of the generated mongoid.yml file.
    #
    # @param [String] contents the contents of mongoid.yml
    #
    # @return [ String ] the updated contents
    def insert_key_vault_config(contents)
      position = (contents =~ /^\s*# Defines the default client/)
      unless position
        say_error 'Default mongoid.yml format has changed; cannot update it with key-vault settings'
        return contents
      end

      indent_size = contents[position..][/^\s*/].length
      contents[position, 0] = KEY_VAULT_CONFIG.indent(indent_size).gsub(/%app%/, app_name)

      contents
    end

    # Returns the path to the downloaded crypt-shared library.
    #
    # @return [ String ] path to the crypt_shared library.
    def crypt_shared_path
      ext = if OS.windows? || OS::Underlying.windows?
              'dll'
            elsif OS.mac?
              'dylib'
            else
              'so'
            end

      # excuse the final '# >'' at the end of the next line...this string
      # confuses vscode's syntax highlighter, and that final comment is
      # to shake it back to its senses...
      %{"<%= Rails.root.join('vendor', 'crypt_shared', 'mongo_crypt_v1.#{ext}') %>"} # >
    end

    # Attempts to insert the auto-encryption configuration into the given
    # string, which must be the contents of the generated mongoid.yml file.
    #
    # @param [String] contents the contents of mongoid.yml
    #
    # @return [ String ] the updated contents
    def insert_auto_encryption_options(contents)
      position = (contents =~ /\sdefault:.*?\s+options:\n/m)

      unless position
        say_error 'Default mongoid.yml format has changed; cannot update it with auto-encryption settings'
        return contents
      end

      position += Regexp.last_match(0).length

      indent_size = contents[position..][/^\s*/].length
      contents[position, 0] = AUTO_ENCRYPTION_CONFIG
                              .indent(indent_size)
                              .gsub(/%crypt-shared-path%/, crypt_shared_path)

      contents
    end

    # Attempts to enable the preload_models option in the given
    # string, which must be the contents of the generated mongoid.yml file.
    #
    # @param [String] contents the contents of mongoid.yml
    #
    # @return [ String ] the updated contents
    def insert_preload_models_option(contents)
      position = (contents =~ /^\s+# preload_models: .*?\n/)

      unless position
        say_error 'Default mongoid.yml format has changed; cannot enable preload_models'
        return contents
      end

      length = Regexp.last_match(0).length

      indent_size = contents[position..][/^\s*/].length
      contents[position, length] = PRELOAD_MODELS_OPTION.indent(indent_size)

      contents
    end
  end
end
