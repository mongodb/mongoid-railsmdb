# frozen_string_literal: true

require 'fileutils'
require 'active_support/core_ext/array/extract_options'
require 'process_interaction_manager'
require 'working_directory_manager'

PROJECT_ROOT = File.expand_path('../..', __dir__)
RAILSMDB_CMD = 'railsmdb'
RAILSMDB_FULL_PATH = File.join(PROJECT_ROOT, 'bin', RAILSMDB_CMD)
RAILSMDB_SANDBOX = File.join(PROJECT_ROOT, 'tmp/railsmdb-sandbox')
MAX_SUMMARY_LENGTH = 50

MONGO_CUSTOMER_PROMPT = /I am a MongoDB customer.*=> \[yes, no\]/
MONGO_SETUP_CONTINUE_PROMPT = /Do you wish to proceed/

# helper function that will try to summarize the given string,
# but keep it to the requested maximum length. If the string is too
# long, the middle part of the string will be elided and replaced with
# an ellipsis.
def maybe_summarize(string, max_length: MAX_SUMMARY_LENGTH)
  if string.length > max_length
    # allocate 3 additional characters for the ellipsis
    first_half = max_length / 2
    last_half = first_half - 3
    "#{string[0, first_half]}...#{string[-last_half..]}"
  else
    string
  end
end

PREFIX_PROJECT_ROOT = /^#{PROJECT_ROOT}/
PREFIX_RAILSMDB_SANDBOX = /^#{RAILSMDB_SANDBOX}/

# If the given command is an absolute path, strip out any prefix that
# matches PROJECT_ROOT or RAILSMDB_SANDBOX.
def abbreviate_command(command)
  command
    .sub(PREFIX_PROJECT_ROOT, '[root]')
    .sub(PREFIX_RAILSMDB_SANDBOX, '[sandbox]')
end

# Normalize the command by looking for common macros that should be
# expanded or replaced.
#
# @param [ String ] command the command to normalize
#
# @return [ String ] the normalized command
def normalize_command(command)
  case command
  when :railsmdb then RAILSMDB_FULL_PATH
  else command
  end
end

# helper function that takes an array of command-line arguments and
# joins them together into a single string, escaping characters as
# necessary to make them safe for a (bash) command-line.
def build_cmd_from_list(command, list)
  [
    command,
    *list.map { |arg| arg.gsub(/[ !?&]/) { |m| "\\#{m}" } }
  ].join(' ')
end

RSpec.configure do
  # Returns the WorkingDirectoryManager in use for the current suite.
  def working_directory
    @working_directory ||= WorkingDirectoryManager.new(RAILSMDB_SANDBOX)
  end

  # Returns the path to the given fixture.
  #
  # @param [ String | Symbol ] kind The type of the fixture (config, etc.)
  # @param [ String | Symbol ] name The name of the fixture
  #
  # @return [ String ] the path name of the given fixture
  def fixture_path_for(kind, name)
    File.join(File.expand_path('../fixtures', __dir__), kind.to_s, name.to_s)
  end

  # Read fixture data from the given fixture.
  #
  # @param [ String | Symbol ] kind The type of the fixture (config, etc.)
  # @param [ String | Symbol ] name The name of the fixture
  #
  # @return [ String ] the contents of the given fixture
  def fixture_from(kind, name)
    File.read(fixture_path_for(kind, name))
  end

  # Write a file at the given path, relative to the containing folder.
  #
  # @param [ String ] relative_path The path, relative to the containing folder
  # @param [ String ] contents The contents of the file to write.
  def write_file(relative_path, contents)
    File.write(working_directory.join(relative_path), contents)
  end

  # Declares a new context, and resets the railsmdb sandbox directory.
  def clean_context(name, &block)
    context name do
      before :context do
        FileUtils.rm_rf RAILSMDB_SANDBOX
      end

      class_exec(&block)
    end
  end

  # Invoke the given command, with the given arguments and environment. If
  # any prompts are given, run the command interactively, responding to the
  # given prompts with the corresponding replies.
  #
  # @param [ String ] command the command to run
  # @param [ Array<String> ] args the arguments to provide to the command
  # @param [ Hash<String,String> ] env the environment to use with the command
  # @param [ true | false ] clean whether the sandbox ought to be wiped out or not
  def when_running(command, *args, env: {}, prompts: {}, clean: false, &block)
    command = normalize_command(command)
    command = build_cmd_from_list(command, args)

    context "when running `#{abbreviate_command(command)}`" do
      before :context do
        FileUtils.rm_rf RAILSMDB_SANDBOX if clean

        working_directory.execute do
          results = if prompts.any?
                      capture_with_interaction(env, command, prompts)
                    else
                      capture_without_interaction(env, command)
                    end

          @stdout, @stderr, @status = results
        end
      end

      class_exec(&block)
    end
  end

  # Tests that the `@status` variable is zero.
  def it_succeeds
    it 'succeeds' do
      expect(@status).to \
        be == 0,
        "status is #{@status}, stderr is #{@stderr.inspect}"
    end
  end

  # Tests that the `@status` variable is not zero.
  def it_fails
    it 'fails' do
      expect(@status).not_to \
        be == 0,
        "status is #{@status}, stdout is #{@stdout.inspect}"
    end
  end

  # Tests that the `@stdout` variable includes the argument
  def it_prints(output)
    it "prints #{maybe_summarize(output.inspect)}" do
      expect(ignore_newlines(@stdout)).to include(output)
    end
  end

  # Tests that the `@stderr` variable includes the argument
  def it_warns(output)
    it "warns #{maybe_summarize(output.inspect)}" do
      expect(ignore_newlines(@stderr)).to include(output)
    end
  end

  # Tests that the given key exists in the encrypted credentials file
  def it_stores_credentials_for(key)
    it "stores credentials for #{key.inspect}" do
      working_directory.execute do
        expect(credentials_file).to match(/^#{key}: /)
      end
    end
  end

  # Tests that the given key does not exist in the encrypted credentials file
  def it_does_not_store_credentials_for(key)
    it "does not store credentials for #{key.inspect}" do
      working_directory.execute do
        expect(credentials_file).not_to match(/^#{key}: /)
      end
    end
  end

  # Tests that the given file is emitted under the current directory.
  # If `without` is given, it may be either a single value or an array,
  # and the file is checked to ensure that it contains none of those
  # values. If `containing` is given, it also may be either a single
  # value or an array, and the file is checked to ensure that it
  # contains all of those values.
  def it_emits_file(path, without: nil, containing: nil)
    file_at path do
      it 'is emitted' do
        expect(File.file?(full_path)).to be true
      end

      it_contains(containing) if containing
      it_does_not_contain(without) if without
    end
  end

  # Like `it_emits_file`, but it ensures a file or directory matching the
  # given glob pattern exists.
  def it_emits_entry_matching(pattern)
    entry_at pattern, type: 'entry matching' do
      it 'is emitted' do
        expect(Dir.glob(full_path)).not_to be_empty
      end
    end
  end

  # Tests that file indicated by the `full_path` let variable
  # includes all of the given patterns.
  def it_contains(patterns)
    Array(patterns).each do |pattern|
      it "contains #{maybe_summarize(pattern.inspect)}" do
        if pattern.is_a?(Regexp)
          expect(file_contents).to match(pattern)
        else
          expect(file_contents).to include(pattern)
        end
      end
    end
  end

  # Tests that file indicated by the `full_path` let variable
  # includes none of the given patterns.
  def it_does_not_contain(patterns)
    Array(patterns).each do |pattern|
      it "does not contain #{maybe_summarize(pattern.inspect)}" do
        if pattern.is_a?(Regexp)
          expect(file_contents).not_to match(pattern)
        else
          expect(file_contents).not_to include(pattern)
        end
      end
    end
  end

  # Tests that the folder at the given path (relative to the current
  # directory) exists.
  def it_emits_folder(path)
    folder_at path do
      it 'is emitted' do
        expect(File.exist?(full_path)).to be true
      end
    end
  end

  # Tests that the entry (file or folder) at the given path (relative to the
  # current directory) does not exist.
  def it_does_not_emit_entry(path, type: 'file')
    entry_at(path, type: type) do
      it 'is not emitted' do
        expect(File.exist?(full_path)).to be false
      end
    end
  end
  alias it_does_not_emit_file it_does_not_emit_entry

  # Tests that the folder at the given path (relative to the
  # current directory) does not exist.
  def it_does_not_emit_folder(path)
    it_does_not_emit_entry(path, type: 'folder')
  end

  # Tests that the file at the given path (relative to the
  # current directory) is a link, and (if to is given) that it links
  # to that path (which may be relative to the current directory)
  def it_links_file(path, to: nil)
    file_at(path) do
      it_is_a_link
      it_links(to) if to
    end
  end

  # Tests that the file at the given path (relative to the
  # current directory) is not link.
  def it_does_not_link_file(path)
    file_at(path) do
      it_is_not_a_link
    end
  end

  # Tests that the file at the `full_path` let variable is a link.
  def it_is_a_link
    it 'is a link' do
      expect(File.symlink?(full_path)).to be true
    end
  end

  # Tests that the file at the `full_path` let variable is not a link.
  def it_is_not_a_link
    it 'is not a link' do
      expect(File.symlink?(full_path)).to be false
    end
  end

  # Tests that the file at the `full_path` let variable links to the
  # (possibly relative) path.
  def it_links(to)
    let(:full_target_path) do
      if to.start_with?('/')
        to
      else
        working_directory.join(to)
      end
    end

    it "links to '#{to}'" do
      expect(File.readlink(full_path)).to be == full_target_path
    end
  end

  # Opens a context block and declares a `full_path` let variable
  # containing the fully-qualified path.
  def entry_at(path, type: 'file', &block)
    context "#{type} '#{path}'" do
      let(:full_path) { working_directory.join(path) }
      let(:file_contents) { File.read(full_path) }

      class_exec(&block)
    end
  end
  alias file_at entry_at

  # Opens a context block and declares a `full_path` let variable
  # containing the fully-qualified path.
  def folder_at(path, &block)
    entry_at(path, type: 'folder', &block)
  end

  # Opens a context block and declares a `containing_folder` let variable
  # containing the fully-qualified path.
  def within_folder(path, &block)
    context "and, under '#{path}'" do
      before(:context) do
        working_directory.push path
      end

      after(:context) do
        working_directory.pop
      end

      class_exec(&block)
    end
  end

  # Runs the given command, with the given environment and arguments.
  # If any output matches any of the keys in `prompts`, the corresponding
  # string will be written to stdin.
  #
  # @param [ Hash ] env the environment to use
  # @param [ String ] command the command to invoke
  # @param [ Hash ] prompts the prompts to interact with
  #
  # @return [ Array<String,String,Integer> ] the status, stdout, and stderr
  #   returned as a 3-tuple.
  def capture_with_interaction(env, command, prompts)
    manager = ProcessInteractionManager.new(env, command, prompts)
    result = manager.run

    [ result[:stdout], result[:stderr], result[:status] ]
  end

  # Runs the given command, with the given environment and arguments.
  #
  # @param [ Hash ] env the environment to use
  # @param [ String ] command the command to invoke
  #
  # @return [ Array<String,String,Integer> ] the status, stdout, and stderr
  #   returned as a 3-tuple.
  def capture_without_interaction(env, command)
    Open3.capture3(env, command)
  end

  # @return [ String ] the contents of the encrypted rails credential
  #   file.
  def credentials_file
    working_directory.execute do
      `EDITOR=cat bin/rails credentials:edit 2>&1`
    end
  end

  # Replaces all newlines and carriage returns in the given string with
  # a single space, and then collapses sequences of two or more spaces to
  # a single space.
  def ignore_newlines(string)
    string.gsub(/\r\n|\r|\n/, ' ').gsub(/\s\s+/, ' ')
  end
end
