# frozen_string_literal: true

# A utility class for managing a directory 'stack', or history.
class WorkingDirectoryManager
  # Create a new WorkingDirectoryManager with the given initial path.
  def initialize(initial_path)
    @initial_path = initial_path
    @stack = []
  end

  # Go back to the previous working directory. If no prior working directory
  # exists, raises an exception.
  def pop
    raise 'currently at the top of the workdir stack; cannot go back farther' if @stack.empty?

    @stack.pop
  end

  # Pushes the given path onto the stack. If it is a relative path, it
  # will be expanded relative to the current working directory.
  #
  # @param [ String ] path the path to push onto the stack
  def push(path)
    path = File.expand_path(path, cwd) unless path.start_with?('/')
    @stack.push(path)
  end

  # Returns the current working directory. This is either the last element
  # on the stack, or (if the stack is empty) the initial path that was
  # given when the manager was instantiated.
  def cwd
    @stack.last || @initial_path
  end

  # Returns a new path with the given arguments joined to the current
  # working directory.
  def join(*args)
    File.join(cwd, *args)
  end

  # Invoke the given block after ensuring the current working directory
  # exists, and changing to that directory.
  def execute
    FileUtils.mkdir_p(cwd)
    Dir.chdir(cwd) { yield cwd }
  end
end
