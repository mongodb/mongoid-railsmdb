# frozen_string_literal: true

require 'rails/generators'
require 'railsmdb/ext/rails/command/behavior'

module Rails
  module Generators # :nodoc:
    class << self
      private

      # Prepends the railsmdb generators lookup path to the existing rails
      # lookup paths.
      def railsmdb_lookup_paths
        @railsmdb_lookup_paths ||= [ 'railsmdb/generators', *rails_lookup_paths ]
      end

      alias rails_lookup_paths lookup_paths
      alias lookup_paths railsmdb_lookup_paths
    end
  end
end
