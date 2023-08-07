# frozen_string_literal: true

require 'rails/command/base'
require 'railsmdb/generators/setup/setup_generator'

module Mongoid
  module Command
    # The implementation of the `setup` command for Railsmdb.
    class SetupCommand < Rails::Command::Base
      desc 'setup', 'Install railsmdb into an existing Rails app'
      def perform(*args)
        # remove the first argument, which will be `setup`, and pass
        # the rest through to the generator
        args.shift

        Railsmdb::Generators::SetupGenerator.start(args)
      end
    end
  end
end
