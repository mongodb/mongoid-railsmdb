# frozen_string_literal: true

require 'railsmdb/version'
require 'rails/generators/rails/app/app_generator'
require 'mongoid'

module Rails
  module Generators
    # Monkeypatch the Rails AppGenerator class to make it emit a Mongoid-friendly
    # application.
    #
    # @private
    class AppGenerator
      # add the Railsmdb templates folder to the source path
      source_paths.unshift File.join(__dir__, 'templates')

      # change the --skip-active-record option to default to true. Users
      # may pass --no-skip-active-record to enable it again, if they want
      # to use both Mongoid and ActiveRecord.
      class_option :skip_active_record, type: :boolean,
                                        aliases: '-O',
                                        default: true,
                                        desc: 'Skip Active Record files'

      # Emit the mongoid.yml file to the new application folder. The
      # mongoid.yml file is taken directly from the installed mongoid
      # gem.
      def mongoid_yml
        file = Gem.find_files('rails/generators/mongoid/config/templates/mongoid.yml').first
        database_name = app_name
        template file, 'config/mongoid.yml', context: binding
      end

      # Emit the mongoid.rb initializer. Unlike mongoid.yml, this is not
      # taken from the mongoid gem, because mongoid versions prior to 9
      # did not include an initializer template.
      def mongoid_initializer
        template '_config/initializers/mongoid.rb', 'config/initializers/mongoid.rb'
      end

      # Emit the bin/railsmdb script to the new app's bin folder. The
      # existing bin/rails script is removed, and replaced by a link to
      # bin/railsmdb.
      def railsmdb
        template '_bin/railsmdb', 'bin/railsmdb' do |content|
          "#{shebang}\n" + content
        end

        chmod 'bin/railsmdb', 0o755, verbose: false

        remove_file 'bin/rails', verbose: false
        create_link 'bin/rails', File.expand_path('bin/railsmdb', destination_root), verbose: false
      end

      # OVERRIDES
      # The following methods override the existing methods on AppGenerator,
      # to replace the default behavior with Mongoid-specific behavior.

      # Overridden to ignore the "skip_active_record" guard. We always want the
      # db folder, even when active record is being skipped.
      def create_db_files
        build(:db)
      end

      # Overridden to save the current directory; this way, we can see
      # if it is being run from the railsmdb project directory, in
      # development, and set up the railsmdb gem dependency appropriately.
      def create_root
        @initial_path = Dir.pwd
        super
      end

      # Overridden to append the mongoid gem entries to the Gemfile.
      def run_bundle
        add_mongoid_gem_entries
        super
      end

      private

      # Returns the Railsmdb project directory if run from inside a
      # checkout of the railsmdb repository. Otherwise, returns nil.
      #
      # @return [ String | nil ] the railsmdb project directory, or nil
      #   if not run within a railsmdb checkout.
      def railsmdb_project_directory
        return @railsmdb_project_directory if defined?(@railsmdb_project_directory)

        @railsmdb_project_directory ||= begin
          path = @initial_path

          while path != '.'
            break if File.exist?(File.join(path, 'railsmdb.gemspec'))

            path = File.dirname(path)
          end

          (path == '.') ? nil : path
        end
      end

      # Appends the mongoid gem entries to the Gemfile.
      def add_mongoid_gem_entries
        mongoid_gem_entries.each do |group, list|
          append_to_file 'Gemfile' do
            prefix = group ? "\ngroup :#{group} do\n" : "\n"
            suffix = group ? "\nend\n" : "\n"
            indent_size = group ? 2 : 0

            prefix +
              list.map { |entry| indent_entry(entry, indent_size) }
                  .join("\n\n") +
              suffix
          end
        end
      end

      # Adds indentation to the string representation of the given
      # gem entry.
      #
      # @param [ Rails::Generators::AppBase::GemfileEntry ] entry The
      #   GemfileEntry instance to format.
      # @param [ Integer ] indent_size the number of spaces to prepend
      #   to each line of the entry's string representation.
      #
      # @return [ String ] the string representation of the given entry
      #   with each line indented by the given number of spaces.
      def indent_entry(entry, indent_size)
        if indent_size < 1
          entry.to_s
        else
          indent = ' ' * indent_size
          entry.to_s.gsub(/^/, indent)
        end
      end

      # The gem entries to be appended to the Gemfile, sorted by gem
      # group.
      #
      # @return [ Hash ] a hash where the keys are the gem groups, and
      #   the values are lists of gem entries corresponding to those
      #   groups.
      def mongoid_gem_entries
        {
          nil => [
            mongoid_gem_entry,
            railsmdb_gem_entry
          ]
        }
      end

      # The gem entry for the Mongoid gem. The version is set to whichever
      # version is installed and active.
      #
      # @return [ Rails::Generators::AppBase::GemfileEntry ] the gem
      #   entry for Mongoid.
      def mongoid_gem_entry
        GemfileEntry.version \
          'mongoid',
          ::Mongoid::VERSION,
          'Use MongoDB for the database, with Mongoid as the ODM'
      end

      # The gem entry for the Railsmdb gem. If run from a railsmdb
      # checkout, the gem will reference the path to that checkout.
      # Otherwise, the version is set to whichever
      # version is installed and active.
      #
      # @return [ Rails::Generators::AppBase::GemfileEntry ] the gem
      #   entry for Railsmdb.
      def railsmdb_gem_entry
        if railsmdb_project_directory.present?
          GemfileEntry.path \
            'mongoid-railsmdb',
            railsmdb_project_directory,
            'The development version of railsmdb'
        else
          GemfileEntry.version \
            'mongoid-railsmdb',
            Railsmdb::Version::STRING,
            'The Rails CLI tool for MongoDB'
        end
      end
    end
  end
end
