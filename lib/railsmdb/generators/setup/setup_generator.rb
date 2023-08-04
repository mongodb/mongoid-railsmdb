# frozen_string_literal: true

require 'rails/generators/base'
require 'railsmdb/generators/setup/concerns/setuppable'

module Railsmdb
  module Generators
    # The implementation of the setup generator for Railsmdb, for
    # configuring railsmdb to work in an existing Rails application.
    class SetupGenerator < Rails::Generators::Base
      include Railsmdb::Generators::Setup::Concerns::Setuppable

      NEED_RAILS_APP_WARNING = <<~WARNING
        The `railsmdb setup` command must be run from the root of an
        existing Rails application. It will add railsmdb to the project,
        prepare the application to use Mongoid for data access, and
        replace the `bin/rails` script with `bin/railsmdb`.

        Please try this command again from the root of an existing Rails
        application.
      WARNING

      ALREADY_HAS_RAILSMDB = <<~WARNING
        This Rails application is already configured to use railsmdb.
      WARNING

      WARN_ABOUT_UNDO = <<~WARNING
        It is strongly recommended to invoke this in a separate branch,
        where you can safely test the changes made by the script and
        roll them back if they cause problems.
      WARNING

      add_shebang_option!

      def ensure_proper_invocation
        ensure_rails_app!
        ensure_not_railsmdb!
        warn_about_undo!
      end

      public_task :save_initial_path
      public_task :confirm_legal_shenanigans
      public_task :fetch_crypt_shared
      public_task :add_mongoid_gem_entries
      public_task :mongoid_yml
      public_task :add_mongodb_local_master_key_to_credentials
      public_task :add_encryption_options_to_mongoid_yml
      public_task :mongoid_initializer
      public_task :railsmdb

      private

      def app_name
        @app_name ||= File.read('config/application.rb').match(/module (\w+)/)[1].underscore
      end

      def ensure_rails_app!
        return if rails_app?

        say NEED_RAILS_APP_WARNING
        exit 1
      end

      def ensure_not_railsmdb!
        return unless railsmdb?

        say ALREADY_HAS_RAILSMDB
        exit 1
      end

      def warn_about_undo!
        say WARN_ABOUT_UNDO
        say

        exit 1 if ask('Do you wish to proceed in the current branch?', limited_to: %w[ yes no ]) == 'no'
      end

      def rails_app?
        File.exist?('bin/rails') &&
          File.exist?('app') &&
          File.exist?('config')
      end

      def railsmdb?
        File.exist?('bin/railsmdb')
      end
    end
  end
end
