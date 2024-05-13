# frozen_string_literal: true

require 'open3'

# A helper class for interacting with a process. Regular expressions are
# given in the form of 'prompts', and if the output of the process
# matches any of the regexes, a corresponding string will be written to
# the process's stdin stream.
#
# @api private
class ProcessInteractionManager
  # @return [ Hash ] additional environment variables to add to the environment
  attr_reader :env

  # @return [ String ] the command to run, with its arguments
  attr_reader :command

  # @return [ Hash<Regexp, String> ] the prompts to look for in the output
  attr_reader :prompts

  # Create a new ProcessInteractionManager.
  #
  # @param [ Hash<String,String> ] env the mapping of environment variables
  #   to include in the environment.
  # @param [ String ] command the full invocation of the command, including
  #   the command itself and all arguments.
  # @param [ Hash<Regexp,String> ] prompts the regexes to look for on the
  #   output, and their corresponding replies.
  def initialize(env, command, prompts)
    @env = env || {}
    @command = command

    # dup, because prompts will be removed from this hash as they are matched.
    @prompts = prompts.dup
  end

  # Invoke the command.
  #
  # @return [ Hash<:stdout,:stderr,:status> ] the result of running the
  #   process. The :stdout and :stderr keys reference strings, and
  #   the :status key references an integer.
  def run
    env['RAILSMDB_SYNC_IO'] = '1'

    Open3.popen3(env, command) do |stdin, stdout, stderr, wait_thr|
      buffers = { stdout => [], stderr => [] }

      loop do
        readers, = IO.select([ stdout, stderr ])
        process_pending_readers(readers, buffers, stdin) or break
      end

      {
        stdout: buffers[stdout].join,
        stderr: buffers[stderr].join,
        status: wait_thr.value.exitstatus
      }
    end
  end

  private

  # Process all of the given readers, appeding output to the corresponding
  # buffers, and looking for recent output that matches the manager's
  # prompts. If any prompts match, the corresponding reply is written to
  # stdin.
  #
  # @param [ Array<IO> | nil ] readers the readers that ought to be checked.
  # @param [ Hash<IO,Array> ] buffers the mapping of IO to array where the
  #   output should be recorded.
  # @param [ IO ] stdin the stdin stream for sending replies to the process
  #
  # @return [ true | false ] returns true if the process is still alive,
  #   false if any of the readers reached end-of-file.
  def process_pending_readers(readers, buffers, stdin)
    (readers || []).each do |reader|
      buffer = buffers[reader]
      buffer << reader.readpartial(4096)

      prompts.keys.each do |prompt|
        if buffer.last.match?(prompt)
          stdin.write(prompts[prompt])

          # only match each prompt once, to avoid duplicate responses
          prompts.delete(prompt)
        end
      end
    end

    true
  rescue EOFError
    false
  end
end
