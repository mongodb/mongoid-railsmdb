# frozen_string_literal: true

require 'mongoid'
require 'rails/command/base'
require 'rails/command/environment_argument'

module Mongoid
  module Command
    # The implementation of the `dbconsole` command for Railsmdb.
    class DbconsoleCommand < Rails::Command::Base
      include Rails::Command::EnvironmentArgument

      desc 'dbconsole', 'Start a console for MongoDB using the info in config/mongoid.yml'
      def perform
        require_application_and_environment!
        exec_mongosh_with(Rails.env || 'default')
      end

      private

      # Invokes mongosh using the config/mongoid.yml configuration for the
      # current Rails environment. If no such configuration exists, it tries
      # to fall back to the `default` configuration.
      #
      # @param [ String ] environment the named configuration to use.
      def exec_mongosh_with(environment)
        puts "Launching mongosh with #{environment} configuration."
        config = find_configuration_for(environment)

        command = ENV['MONGOSH_CMD'] || 'mongosh'

        uri = config[:uri] || "mongodb://#{config[:hosts].first}/#{config[:database]}"

        exec(command, uri)
      rescue Errno::ENOENT
        abort "mongosh is not installed, or is not in your PATH. Please see\n" \
              "https://www.mongodb.com/docs/mongodb-shell for instructions on\n" \
              'downloading and installing mongosh.'
      end

      # Looks for a Mongoid client configuration with the given name. If no
      # such configuration exists, tries to load the `default` configuration.
      # If that can't be found, it will abort executation.
      #
      # @param [ String ] environment the name of the configuration to load.
      #
      # @return [ Hash ] the named configuration
      def find_configuration_for(environment)
        config = Mongoid.clients[environment]
        return config if config

        warn "There is no #{environment} configuration defined in config/mongoid.yml."

        config = Mongoid.clients[:default]
        unless config
          abort "There is no default configuration to fall back to.\n" \
                'Please define a client in config/mongoid.yml.'
        end

        warn 'Using default configuration instead.'
        config
      end
    end
  end
end
