# frozen_string_literal: true

require 'railsmdb/prioritizable'
require 'active_support/encrypted_configuration'
require 'os'
require 'railsmdb/version'
require 'railsmdb/crypt_shared/catalog'
require 'railsmdb/downloader'
require 'railsmdb/extractor'
require 'rails/generators/rails/app/app_generator'
require 'digest'
require 'mongoid'

module Railsmdb
  module Generators
    module Setup
      module Concerns
        # Tasks used for configuring a Rails app to use Mongoid, including
        # adding support for encryption. This concern is shared between
        # the app generator (e.g. `railsmdb new`) and the setup generator
        # (e.g. `railsmdb setup`).
        #
        # @api private
        module Setuppable
          extend ActiveSupport::Concern

          include Railsmdb::Prioritizable

          GemfileEntry = Rails::Generators::AppBase::GemfileEntry

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

          included do
            # add the setup generator templates folder to the source path
            source_paths.unshift File.join(__dir__, '..', 'templates')

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
          end

          # Save the current directory; this way, we can see
          # if it is being run from the railsmdb project directory, in
          # development, and set up the railsmdb gem dependency appropriately.
          def save_initial_path
            @initial_path = Dir.pwd
          end

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
            url, sha = catalog.optimal_download_url_for_this_host

            if url
              fetch_and_extract_crypt_shared_from_url(url, sha)
            else
              say_error 'Cannot find download URL for crypt_shared, for this host'
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

          # Emit the mongoid.yml file to the new application folder. The
          # mongoid.yml file is taken directly from the installed mongoid
          # gem.
          def mongoid_yml
            file = Gem.find_files('rails/generators/mongoid/config/templates/mongoid.yml').first
            database_name = app_name
            template file, 'config/mongoid.yml', context: binding
          end

          # Appends a new local master key to the credentials file
          def add_mongodb_local_master_key_to_credentials
            return unless @okay_to_support_encryption

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

              while path != '/'
                break if File.exist?(File.join(path, 'railsmdb.gemspec'))

                path = File.dirname(path)
              end

              (path == '/') ? nil : path
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
            if @okay_to_support_encryption && ::Mongoid::VERSION < '9.0'
              # FIXME: once Mongoid 9.0 is released, update this so that it
              # uses that released version.
              GemfileEntry.github \
                'mongoid',
                'mongodb/mongoid',
                'master',
                'Encryption requires an unreleased version of Mongoid'
            else
              GemfileEntry.version \
                'mongoid',
                ::Mongoid::VERSION,
                'Use MongoDB for the database, with Mongoid as the ODM'
            end
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
                'railsmdb',
                railsmdb_project_directory,
                'The development version of railsmdb'
            else
              GemfileEntry.version \
                'railsmdb',
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

          # Build the gem entry for the ffi gem.
          #
          # @return [ Rails::Generators::AppBase::GemfileEntry ] the gem
          #   entry for ffi gem.
          def ffi_gem_entry
            GemfileEntry.version \
              'ffi', nil,
              'Mongoid needs the ffi gem when encryption is enabled'
          end

          # If encryption is enabled, adds the necessary gems to the given list
          # of gem entries, to prepare them to be added to the gemfile.
          #
          # @param [ Array<GemfileEntry> ] list The list of gemfile entries.
          def maybe_add_encryption_gems(list)
            return unless @okay_to_support_encryption

            list.push libmongocrypt_helper_gem_entry
            list.push ffi_gem_entry
          end

          # The location of the directory where the crypt_shared library will
          # be saved to, relative to the app root.
          CRYPT_SHARED_DIR = 'vendor/crypt_shared'

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

          CREDENTIALS_FILE_PATH = 'config/credentials.yml.enc'

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
        end
      end
    end
  end
end
