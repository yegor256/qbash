# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require 'backtrace'
require 'logger'
require 'loog'
require 'open3'
require 'tago'

# Execute one bash command.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2026 Yegor Bugayenko
# License:: MIT
module Kernel
  # Execute a single bash command safely with proper error handling.
  #
  # QBash provides a safe way to execute shell commands with proper error handling,
  # logging, and stdin/stdout management. It's designed to be simple for basic use
  # cases while offering powerful options for advanced scenarios.
  #
  # == Basic Usage
  #
  #   # Execute a command and get its output
  #   year = qbash('date +%Y')
  #   puts "Current year: #{year}"
  #
  #   # Execute a command that might fail
  #   files = qbash('find /tmp -name "*.log"')
  #
  # == Working with Exit Codes
  #
  #   # Get both output and exit code
  #   output, code = qbash('grep "error" /var/log/system.log', both: true)
  #   puts "Command succeeded" if code.zero?
  #
  #   # Accept multiple exit codes as valid
  #   result = qbash('grep "pattern" file.txt', accept: [0, 1])
  #
  # == Providing Input via STDIN
  #
  #   # Pass data to command's stdin
  #   result = qbash('wc -l', stdin: "line 1\nline 2\nline 3")
  #
  # == Environment Variables
  #
  #   # Set environment variables for the command
  #   output = qbash('echo $NAME', env: { 'NAME' => 'Ruby' })
  #
  # == Logging
  #
  #   # Enable detailed logging to console
  #   qbash('ls -la', stdout: $stdout)
  #
  #   # Use custom logger with specific level
  #   logger = Logger.new($stdout)
  #   qbash('make all', stdout: logger, level: Logger::INFO)
  #
  # == Process Control
  #
  #   # Get control over long-running process
  #   qbash('sleep 30') do |pid|
  #     puts "Process #{pid} is running..."
  #     # Do something while process is running
  #     # Process will be terminated when block exits
  #   end
  #
  # == Changing Working Directory
  #
  #   # Execute command in a specific directory
  #   files = qbash('ls -la', chdir: '/tmp')
  #
  #   # Useful for commands that operate on the current directory
  #   qbash('git status', chdir: '/path/to/repo')
  #
  # For command with multiple arguments, you can use +Shellwords.escape()+ to
  # properly escape each argument.
  #
  # == Stderr Handling
  #
  # By default, stderr merges with stdout. You can redirect it elsewhere:
  #
  #   # Merge stderr with stdout (default)
  #   output = qbash('cmd', stderr: :stdout)
  #
  #   # Redirect stderr to a separate logger
  #   err_log = Loog::Buffer.new
  #   output = qbash('cmd', stderr: err_log)
  #
  #   # Discard stderr completely
  #   output = qbash('cmd', stderr: nil)
  #
  # Read this <a href="https://github.com/yegor256/qbash">README</a> file for more details.
  #
  # @param [String, Array] cmd The command to run (String or Array of arguments)
  # @param [String] stdin The +stdin+ to provide to the command
  # @param [Array] opts List of bash options, like "--login" and "--noprofile"
  # @param [Hash] env Hash of environment variables
  # @param [Loog|IO] stdout Logging facility with +.debug()+ method (or +$stdout+, or nil if should go to +/dev/null+)
  # @param [Loog|IO] stderr Where to send stderr
  # @param [Array] accept List of accepted exit codes (accepts all if the list is +nil+)
  # @param [Boolean] both If set to TRUE, the function returns an array +(stdout, code)+
  # @param [Integer] level Logging level (use +Logger::DEBUG+, +Logger::INFO+, +Logger::WARN+, or +Logger::ERROR+)
  # @param [String] chdir Directory to change to before running the command (or +nil+ to use current directory)
  # @return [String] Everything that was printed to the +stdout+ by the command
  def qbash(*cmd, opts: [], stdin: '', env: {}, stdout: Loog::NULL, stderr: nil, accept: [0], both: false,
            level: Logger::DEBUG, chdir: nil)
    stderr ||= stdout
    env.each { |k, v| raise "env[#{k}] is nil" if v.nil? }
    cmd = cmd.reject { |a| a.nil? || (a.is_a?(String) && a.empty?) }.join(' ')
    mtd =
      case level
      when Logger::DEBUG
        :debug
      when Logger::INFO
        :info
      when Logger::WARN
        :warn
      when Logger::ERROR
        :error
      else
        raise "Unknown log level #{level}"
      end
    printer =
      lambda do |target, msg|
        msg = msg.encode('UTF-8', invalid: :replace, undef: :replace, replace: '?').gsub(/\n$/, '')
        if target.nil?
          # nothing to print
        elsif target.respond_to?(mtd)
          target.__send__(mtd, msg)
        else
          target.print("#{msg}\n")
        end
      end
    buf = +''
    e = 1
    start = Time.now
    bash = ['/bin/bash'] + opts + ['-c', cmd]
    popen = chdir.nil? ? [env, *bash] : [env, *bash, { chdir: }]
    Open3.send(:popen3, *popen) do |sin, sout, serr, ctrl|
      pid = ctrl.pid
      printer[stderr, "+ #{cmd} /##{pid}"]
      consume =
        lambda do |stream, target, buffer|
          loop do
            sleep 0.001
            break if stream.closed? || stream.eof?
            ln = stream.gets
            next if ln.nil?
            next if ln.empty?
            buffer << ln if buffer
            printer[target, "##{pid}: #{ln}"]
          rescue IOError => e
            printer[stderr, e.message]
            break
          end
        end
      sin.write(stdin)
      sin.close
      if block_given?
        watch = Thread.new { consume.call(sout, stdout, buf) }
        watch.abort_on_exception = true
        begin
          yield pid
        ensure
          sout.close
          serr&.close
          watch.join(0.01)
          watch.kill if watch.alive?
          attempt = 1
          since = Time.now
          loop do
            Process.kill(0, pid)
            Process.kill('TERM', pid)
            printer[stderr, "Tried to stop ##{pid} with SIGTERM (attempt no.#{attempt}, #{since.ago}): #{cmd}"]
            sleep(0.1)
            attempt += 1
          rescue Errno::ESRCH
            if attempt > 1
              printer[stderr,
                      "Process ##{pid} reacted to SIGTERM, after #{attempt} attempts and #{since.ago}"]
            end
            break
          end
        end
      else
        thread = Thread.new { consume.call(serr, stderr, nil) }
        thread.abort_on_exception = true
        consume.call(sout, stdout, buf)
        thread.join
      end
      e = ctrl.value.exitstatus
      if !accept.nil? && !accept.include?(e)
        raise "The command '#{cmd}' failed with exit code ##{e} in #{start.ago}\n#{buf}"
      end
    end
    return [buf, e] if both
    buf
  end
end
