# frozen_string_literal: true

require 'rails/generators/base'
require 'railsmdb/helpers'

if ENV['RAILSMDB_SYNC_IO'] == '1'
  $stderr.sync = true
  $stdout.sync = true
end

module Railsmdb
  module Generators
    # The implementation of the setup generator for Railsmdb, for
    # configuring railsmdb to work in an existing Rails application.
    class SetupGenerator < Rails::Generators::Base
      include Railsmdb::Helpers

      source_paths.unshift File.join(__dir__, 'templates')

      # An option for enabling MongoDB encryption features in the app.
      class_option :encryption, type: :boolean,
                                aliases: '-E',
                                default: false,
                                desc: 'Add gems and configuration to enable MongoDB encryption features'

      # Add an option for accepting the customer agreement related to
      # MongoDB enterprise, allowing the acceptance prompt to be skipped.
      class_option :accept_customer_agreement, type: :boolean,
                                               desc: 'Accept the MongoDB Customer Agreement'

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

      # Make sure the current directory is an appropriate place to
      # run this generator. It must:
      #   - be the root directory of a Rails project
      #   - not already have been set up with railsmdb
      #
      # Additionally, this will encourage the user to run this generator
      # in a branch, in order to safely see what it does to their app.
      def ensure_proper_invocation
        ensure_rails_app!
        ensure_railsmdb_not_already_present!
        warn_about_undo!
      end

      public_task :mongoid_gem
      public_task :railsmdb_gem

      public_task :confirm_legal_shenanigans
      public_task :possibly_support_encryption

      def run_bundle
        say_status :run, 'bundle install'
        cmd = "#{Gem.ruby} #{Gem.bin_path("bundler", "bundle")} install --quiet"

        require "bundler"
        Bundler.with_original_env { system(cmd) }
      end

      public_task :emit_mongoid_yml
      public_task :add_encryption_options_to_mongoid_yml

      public_task :emit_mongoid_initializer
      public_task :emit_railsmdb

      private

      # Infers the name of the app from the application's config/application.rb
      # file.
      #
      # @return [ String ] the name of the application
      def app_name
        @app_name ||= File.read('config/application.rb').match(/module (\w+)/)[1].underscore
      end

      # Warns and exits if the current directory is not the root of a
      # Rails project.
      def ensure_rails_app!
        return if rails_app?

        warn NEED_RAILS_APP_WARNING
        exit 1
      end

      # Warns and exits if railsmdb is already present in the current
      # Rails project.
      def ensure_railsmdb_not_already_present!
        return unless railsmdb?

        warn ALREADY_HAS_RAILSMDB
        exit 1
      end

      # Encourages the user to run this in a branch so that the changes
      # may be easily rolled back.
      #
      # If the user chooses not to proceed, this method will exit the
      # program.
      def warn_about_undo!
        warn WARN_ABOUT_UNDO
        say

        exit 0 if ask('Do you wish to proceed in the current branch?', limited_to: %w[ yes no ]) == 'no'
      end

      # Returns true if the current directory appears to be a Rails app.
      #
      # @return [ true | false ] if the current directory is a Rails app
      #   or not.
      def rails_app?
        File.exist?('bin/rails') &&
          File.exist?('app') &&
          File.exist?('config')
      end

      # Returns true if railsmdb appears to already be present in the
      # current Rails app.
      #
      # @return [ true | false ] if railsmdb is already present.
      def railsmdb?
        File.exist?('bin/railsmdb')
      end
    end
  end
end
