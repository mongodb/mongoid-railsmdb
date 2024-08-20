# frozen_string_literal: true

require 'rails/command/behavior'

module Railsmdb
  # Extensions to the Rails::Command::Behavior module
  module RailsCommandBehaviorExtension
    module ClassMethods # :nodoc:
      private

      # Railsmdb's version of `Command#lookup`, which makes
      # sure any `rails:` namespace is preempted by a corresponding
      # `railsmdb:` namespace.
      #
      # @param [ Array<String> ] namespaces the list of namespaces
      #   to look at
      def lookup(namespaces)
        super(preempt_rails_namespace(namespaces))
      end

      # If a "rails:" namespace exists in the list,
      # insert a new namespace before it with "rails:"
      # replaced with "mongoid:"
      #
      # @param [ Array<String> ] namespaces the list of namespaces
      #   to consider
      #
      # @return [ Array<String> ] the (possibly modified) list of
      #   namespaces.
      def preempt_rails_namespace(namespaces)
        new_namespaces = []

        namespaces.each do |ns|
          if ns.match?(/\brails:/)
            new_ns = ns.sub(/\brails:/, 'mongoid:')
            new_namespaces.push(new_ns)
          end

          new_namespaces.push(ns)
        end

        # we need to replace the namespaces list in-place, so that the caller
        # gets the updated namespaces.
        namespaces.replace(new_namespaces)
      end
    end

    ::Rails::Command::Behavior::ClassMethods.prepend ClassMethods
  end
end
