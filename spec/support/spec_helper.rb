# frozen_string_literal: true

require 'open3'
require 'fileutils'
require 'active_support/core_ext/array/extract_options'

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
  # Read fixture data from the given fixture.
  #
  # @param [ String | Symbol ] kind The type of the fixture (config, etc.)
  # @param [ String | Symbol ] name The name of the fixture
  #
  # @return [ String ] the contents of the given fixture
  def fixture_from(kind, name)
    File.read(File.join(File.expand_path('../fixtures', __dir__), kind.to_s, name.to_s))
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
  def when_running_railsmdb(*args, &block)
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

        let_railsmdb_decls(RAILSMDB_FULL_PATH, arg_str, from_path: RAILSMDB_SANDBOX)

        class_exec(&block)
      end
    end
  end

  # helper for declaring let() variables related to the invocation of
  # the railsmdb command. The `railsmdb` variable returns the out and
  # err streams, and the status as a 3-tuple. `railsmdb_out`,
  # `railsmdb_err`, and `railsmdb_status` variables are available for
  # convenience in accessing the elements of that tuple.
  def let_railsmdb_decls(command, args, from_path: nil, env: {})
    env_str = env.map { |h, k| "#{h}=#{k}" }.join(' ')

    before :context do
      Dir.chdir(from_path || containing_folder) do
        @railsmdb_out, @railsmdb_err, @railsmdb_status =
          Open3.capture3("#{env_str} #{command} #{args}")
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
      let_railsmdb_decls(RAILSMDB_FULL_PATH, arg_str, **opts)

      class_exec(&block)
    end
  end

  # Tests that the `railsmdb_status` is zero.
  def it_succeeds
    it 'succeeds' do
      expect(@railsmdb_status).to be == 0
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

  # Tests that file indicated by the `full_path` let variable
  # includes all of the given patterns.
  def it_contains(patterns)
    Array(patterns).each do |pattern|
      it "contains #{maybe_summarize(pattern.inspect)}" do
        content = File.read(full_path)
        expect(content).to include(pattern)
      end
    end
  end

  # Tests that file indicated by the `full_path` let variable
  # includes none of the given patterns.
  def it_does_not_contain(patterns)
    Array(patterns).each do |pattern|
      it "does not contain #{maybe_summarize(pattern.inspect)}" do
        content = File.read(full_path)
        expect(content).not_to include(pattern)
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
end
# rubocop:enable Lint/NestedMethodDefinition
