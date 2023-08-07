# frozen_string_literal: true

require 'railsmdb/generators/setup/concerns/setuppable'

module Rails
  module Generators
    # Monkeypatch the Rails AppGenerator class to make it emit a Mongoid-friendly
    # application.
    #
    # @api private
    class AppGenerator
      include Railsmdb::Generators::Setup::Concerns::Setuppable

      # change the --skip-active-record option to default to true. Users
      # may pass --no-skip-active-record to enable it again, if they want
      # to use both Mongoid and ActiveRecord.
      class_option :skip_active_record, type: :boolean,
                                        aliases: '-O',
                                        default: true,
                                        desc: 'Skip Active Record files'

      prioritize :save_initial_path, :before, :create_root
      prioritize :confirm_legal_shenanigans, :before, :create_root
      prioritize :fetch_crypt_shared, :after, :create_root
      prioritize :add_mongoid_gem_entries, :before, :run_bundle

      public_task :save_initial_path
      public_task :confirm_legal_shenanigans
      public_task :fetch_crypt_shared
      public_task :add_mongoid_gem_entries
      public_task :mongoid_yml
      public_task :add_mongodb_local_master_key_to_credentials
      public_task :add_encryption_options_to_mongoid_yml
      public_task :mongoid_initializer
      public_task :railsmdb

      # OVERRIDES
      # The following methods override the existing methods on AppGenerator,
      # to replace the default behavior with Mongoid-specific behavior.

      # Overridden to ignore the "skip_active_record" guard. We always want the
      # db folder, even when active record is being skipped.
      def create_db_files
        build(:db)
      end
    end
  end
end
