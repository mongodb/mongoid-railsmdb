# frozen_string_literal: true

require 'fileutils'
require 'active_support/core_ext/array/extract_options'
require 'support/process_interaction_manager'

PROJECT_ROOT = File.expand_path('../..', __dir__)
RAILSMDB_CMD = 'railsmdb'
RAILSMDB_FULL_PATH = File.join(PROJECT_ROOT, 'bin', RAILSMDB_CMD)
RAILSMDB_SANDBOX = File.join(PROJECT_ROOT, 'tmp/railsmdb-sandbox')
MAX_SUMMARY_LENGTH = 50

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

# helper function that takes an array of command-line arguments and
# joins them together into a single string, escaping characters as
# necessary to make them safe for a (bash) command-line.
def build_args_from_list(list)
  list.map { |arg| arg.gsub(/[ !?&]/) { |m| "\\#{m}" } }.join(' ')
end

# rubocop:disable Lint/NestedMethodDefinition
RSpec.configure do
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
    File.write(File.join(containing_folder, relative_path), contents)
  end

  # Begins a new context block for invoking the Railsmdb project's railsmdb
  # script, and yields to the given block.
  #
  # @note When running this command with the `prompts` argument, you must make
  #   sure that the process being invoked is run with output buffering
  #   disabled. For Ruby programs, this means explicitly calling
  #   `STDOUT.sync = true` in the invoked script.
  def when_running_railsmdb(*args, &block)
    opts = args.extract_options!

    FileUtils.mkdir_p RAILSMDB_SANDBOX

    Dir.chdir(RAILSMDB_SANDBOX) do
      arg_str = build_args_from_list(args)

      context "when running `#{RAILSMDB_CMD} #{arg_str}`" do
        def containing_folder
          RAILSMDB_SANDBOX
        end

        before :context do
          FileUtils.rm_rf RAILSMDB_SANDBOX
          FileUtils.mkdir_p RAILSMDB_SANDBOX
        end

        invoke_railsmdb(RAILSMDB_FULL_PATH, arg_str, from_path: RAILSMDB_SANDBOX, **opts)

        class_exec(&block)
      end
    end
  end

  # helper for declaring let() variables related to the invocation of
  # the railsmdb command. The `railsmdb` variable returns the out and
  # err streams, and the status as a 3-tuple. `railsmdb_out`,
  # `railsmdb_err`, and `railsmdb_status` variables are available for
  # convenience in accessing the elements of that tuple.
  def invoke_railsmdb(command, args, from_path: nil, env: {}, prompts: {})
    before :context do
      Dir.chdir(from_path || containing_folder) do
        if prompts.any?
          capture_with_interaction(env, command, args, prompts)
        else
          capture_without_interaction(env, command, args)
        end
      end
    end
  end

  # Begins a new context block for invoking a Rails project's railsmdb
  # script, and yields to the given block. It is assumed that the
  # Rails project is the current directory.
  def when_running_bin_railsmdb(*args, &block)
    opts = args.extract_options!
    arg_str = build_args_from_list(args)

    context "when running `#{RAILSMDB_CMD} #{arg_str}`" do
      invoke_railsmdb(RAILSMDB_FULL_PATH, arg_str, **opts)

      class_exec(&block)
    end
  end

  # Tests that the `railsmdb_status` is zero.
  def it_succeeds
    it 'succeeds' do
      expect(@railsmdb_status).to \
        be == 0,
        "status is #{@railsmdb_status}, stderr is #{@railsmdb_err.inspect}"
    end
  end

  # Tests that the given key exists in the encrypted credentials file
  def it_stores_credentials_for(key)
    it "stores credentials for #{key.inspect}" do
      Dir.chdir(containing_folder) do
        expect(credentials_file).to match(/^#{key}: /)
      end
    end
  end

  # Tests that the given key does not exist in the encrypted credentials file
  def it_does_not_store_credentials_for(key)
    it "does not store credentials for #{key.inspect}" do
      Dir.chdir(containing_folder) do
        expect(credentials_file).not_to match(/^#{key}: /)
      end
    end
  end

  # Tests that the `railsmdb_status` is not zero.
  def it_fails
    it 'fails' do
      expect(@railsmdb_status).not_to be == 0
    end
  end

  # Tests that the `railsmdb_out` includes the argument
  def it_prints(output)
    it "prints #{maybe_summarize(output.inspect)}" do
      expect(@railsmdb_out).to include(output)
    end
  end

  # Tests that the `railsmdb_err` includes the argument
  def it_warns(output)
    it "warns #{maybe_summarize(output.inspect)}" do
      expect(@railsmdb_err).to include(output)
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
        content = File.read(full_path)

        if pattern.is_a?(Regexp)
          expect(content).to match(pattern)
        else
          expect(content).to include(pattern)
        end
      end
    end
  end

  # Tests that file indicated by the `full_path` let variable
  # includes none of the given patterns.
  def it_does_not_contain(patterns)
    Array(patterns).each do |pattern|
      it "does not contain #{maybe_summarize(pattern.inspect)}" do
        content = File.read(full_path)

        if pattern.is_a?(Regexp)
          expect(content).not_to match(pattern)
        else
          expect(content).not_to include(pattern)
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

  # Tests that the file at the `full_path` let variable is a link.
  def it_is_a_link
    it 'is a link' do
      expect(File.symlink?(full_path)).to be true
    end
  end

  # Tests that the file at the `full_path` let variable links to the
  # (possibly relative) path.
  def it_links(to)
    let(:full_target_path) do
      if to.start_with?('/')
        to
      else
        File.join(containing_folder, to)
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
      let(:full_path) { File.join(containing_folder, path) }

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
    FileUtils.mkdir_p path

    Dir.chdir path do
      context "and, under '#{path}'" do
        define_method(:containing_folder) { File.join(super(), path) }

        class_exec(&block)
      end
    end
  end

  # Runs the given command, with the given environment and arguments.
  # The stderr and stdout are captured (as @railsmdb_err and @railsmdb_out),
  # and the status is saved (as @railsmdb_status). If any output matches
  # any of the keys in `prompts`, the corresponding string will be written
  # to stdin.
  #
  # @param [ Hash ] env the environment to use
  # @param [ String ] command the command to invoke
  # @param [ String ] args the argument string
  # @param [ Hash ] prompts the prompts to interact with
  def capture_with_interaction(env, command, args, prompts)
    manager = ProcessInteractionManager.new(env, "#{command} #{args}", prompts)
    result = manager.run

    @railsmdb_status = result[:status]
    @railsmdb_out = result[:stdout]
    @railsmdb_err = result[:stderr]
  end

  # Runs the given command, with the given environment and arguments.
  # The stderr and stdout are captured (as @railsmdb_err and @railsmdb_out),
  # and the status is saved (as @railsmdb_status).
  #
  # @param [ Hash ] env the environment to use
  # @param [ String ] command the command to invoke
  # @param [ String ] args the argument string
  def capture_without_interaction(env, command, args)
    @railsmdb_out, @railsmdb_err, @railsmdb_status =
      Open3.capture3(env, "#{command} #{args}")
  end

  # @return [ String ] the contents of the encrypted rails credential
  #   file.
  def credentials_file
    Dir.chdir(containing_folder) do
      `EDITOR=cat bin/rails credentials:edit 2>&1`
    end
  end
end
# rubocop:enable Lint/NestedMethodDefinition
