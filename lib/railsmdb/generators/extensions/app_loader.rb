# frozen_string_literal: true

require 'rails/app_loader'

module Mongoid
  module Generators
    module Extensions
      # Extension module for the Rails::AppLoader module.
      module AppLoader
        RAILSMDB_SCRIPT = 'bin/railsmdb'.freeze

        def find_executable
          File.file?(RAILSMDB_SCRIPT) ? RAILSMDB_SCRIPT : nil
        end
      end

      ::Rails::AppLoader.prepend AppLoader
    end
  end
end
