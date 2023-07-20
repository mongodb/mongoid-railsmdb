# frozen_string_literal: true

require 'rails/command'

module Rails
  module Command # :nodoc:
    class << self
      # this method copy/pasted from Rails, purely so that we could add a
      # higher-priority check for the railsmdb namespace here.
      def find_by_namespace(namespace, command_name = nil)
        lookups = [ namespace ]
        lookups << "#{namespace}:#{command_name}" if command_name
        implicit_scopes = lookups.flat_map { |lookup| %W[ railsmdb:#{lookup} rails:#{lookup} ] }
        lookups.concat(implicit_scopes)

        lookup(lookups)

        namespaces = subclasses.index_by(&:namespace)
        namespaces[(lookups & namespaces.keys).first]
      end
    end
  end
end
