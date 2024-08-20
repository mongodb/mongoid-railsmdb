# frozen_string_literal: true

require 'rails/command'
require 'railsmdb/ext/rails/command/behavior'

module Rails
  module Command # :nodoc:
    class << self
      private

      # Prepends the railsmdb commands lookup path to the existing rails
      # lookup paths.
      #
      # @note This can't be reimplemented in the railsmdb/ext/rails/command/behavior
      # patch because it is not originally implemented on Rails::Command::Behavior.
      def railsmdb_lookup_paths
        @railsmdb_lookup_paths ||= [ 'railsmdb/commands', *rails_lookup_paths ]
      end

      alias rails_lookup_paths lookup_paths
      alias lookup_paths railsmdb_lookup_paths
    end
  end
end
