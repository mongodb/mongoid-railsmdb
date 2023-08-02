# frozen_string_literal: true

require 'active_support/concern'

module Railsmdb
  # Defines the behavior for extending the Thor framework to allow commands
  # to be reprioritized--ensuring they run immediately before or after
  # another command.
  module Prioritizable
    extend ActiveSupport::Concern

    # rubocop:disable Metrics/BlockLength
    class_methods do
      # Override all_commands to return a new hash with the keys in priority
      # order.
      #
      # @return [ Hash ] the commands in priority order
      #
      # rubocop:disable Naming/MemoizedInstanceVariableName
      def all_commands
        @prioritized_all_commands ||= begin
          commands = super.dup

          aside = priorities.keys
          ordered = commands.slice!(*aside)

          {}.tap do |prioritized|
            ordered.each do |key, command|
              add_prioritized_command(prioritized, key, command)
            end
          end
        end
      end
      # rubocop:enable Naming/MemoizedInstanceVariableName

      # @return [ Hash<String, Array<Symbol, Command>> ] the declared priorities, with
      #   each task name referencing a 2-tuple of [priority, command].
      #
      # @api private
      def priorities
        @priorities ||= {}
      end

      # @return [ Hash<String, Hash<(:before|:after), Array>> ] the declared
      #   priorities, organized by the task they are relative to.
      #
      # @api private
      def priorities_by_relative_task
        @priorities_by_relative_task ||= {}
      end

      # Specify that `task` should run before or after another task.
      #
      # @param [ String | Symbol ] task the task to prioritize.
      # @param [ :before | :after ] priority the priority to use
      # @param [ String | Symbol ] other_task the task relative to which to prioritize `task`
      def prioritize(task, priority, other_task)
        raise ArgumentError, 'priority must be either of :before or :after' if priority != :before && priority != :after

        task = task.to_s
        other_task = other_task.to_s

        priorities[task] = [ priority, other_task ]
        priorities_by_relative_task[other_task] ||= { before: [], after: [] }
        priorities_by_relative_task[other_task][priority].push task

        @prioritized_all_commands = nil
      end

      private

      # Adds the given [key, command] pair to the commands mapping, but
      # first recursively considers if any other tasks need to be added
      # before it. Then, after adding [key, command], it recursively
      # considers if any other tasks need to be added after it.
      #
      # @param [ Hash ] commands the mapping of task names to command
      #   objects.
      # @param [ String ] key the name of the task to add
      # @param [ Object ] command the command object
      def add_prioritized_command(commands, key, command)
        priorities = priorities_by_relative_task[key] || {}

        (priorities[:before] || []).each do |earlier|
          add_prioritized_command(commands, earlier, all_tasks[earlier])
        end

        commands[key] = command

        (priorities[:after] || []).each do |later|
          add_prioritized_command(commands, later, all_tasks[later])
        end
      end
    end
    # rubocop:enable Metrics/BlockLength
  end
end
