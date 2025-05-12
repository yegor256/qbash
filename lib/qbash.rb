# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require 'backtrace'
require 'logger'
require 'loog'
require 'open3'
require 'shellwords'
require 'tago'

# Execute one bash command.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2025 Yegor Bugayenko
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
  #   # Enable detailed logging to stdout
  #   qbash('ls -la', log: $stdout)
  #
  #   # Use custom logger with specific level
  #   logger = Logger.new($stdout)
  #   qbash('make all', log: logger, level: Logger::INFO)
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
  # For command with multiple arguments, you can use +Shellwords.escape()+ to
  # properly escape each argument. Stderr automatically merges with stdout.
  #
  # Read this <a href="https://github.com/yegor256/qbash">README</a> file for more details.
  #
  # @param [String, Array] cmd The command to run (String or Array of arguments)
  # @param [String] stdin The +stdin+ to provide to the command
  # @param [Array] opts List of bash options, like "--login" and "--noprofile"
  # @param [Hash] env Hash of environment variables
  # @param [Loog|IO] log Logging facility with +.debug()+ method (or +$stdout+, or nil if should go to +/dev/null+)
  # @param [Array] accept List of accepted exit codes (accepts all if the list is +nil+)
  # @param [Boolean] both If set to TRUE, the function returns an array +(stdout, code)+
  # @param [Integer] level Logging level (use +Logger::DEBUG+, +Logger::INFO+, +Logger::WARN+, or +Logger::ERROR+)
  # @return [String] Everything that was printed to the +stdout+ by the command
  def qbash(cmd, opts: [], stdin: '', env: {}, log: Loog::NULL, accept: [0], both: false, level: Logger::DEBUG)
    env.each { |k, v| raise "env[#{k}] is nil" if v.nil? }
    cmd = cmd.reject { |a| a.nil? || (a.is_a?(String) && a.empty?) }.join(' ') if cmd.is_a?(Array)
    logit =
      lambda do |msg|
        msg = msg.gsub(/\n$/, '')
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
        if log.nil?
          # nothing to print
        elsif log.respond_to?(mtd)
          log.__send__(mtd, msg)
        else
          log.print("#{msg}\n")
        end
      end
    buf = ''
    e = 1
    start = Time.now
    bash = ['exec', '/bin/bash'] + opts + ['-c', Shellwords.escape(cmd)]
    Open3.popen2e(env, bash.join(' ')) do |sin, sout, ctrl|
      pid = ctrl.pid
      logit["+ #{cmd} /##{pid}"]
      consume =
        lambda do
          loop do
            break if sout.eof?
            ln = sout.gets # together with the \n at the end
            next if ln.nil?
            next if ln.empty?
            buf += ln
            ln = "##{ctrl.pid}: #{ln}"
            logit[ln]
          rescue IOError => e
            logit[e.message]
            break
          end
        end
      sin.write(stdin)
      sin.close
      if block_given?
        watch = Thread.new { consume.call }
        watch.abort_on_exception = true
        yield pid
        sout.close
        watch.join(0.01)
        watch.kill if watch.alive?
        attempt = 1
        since = Time.now
        loop do
          Process.kill(0, pid) # should be dead already (raising Errno::ESRCH)
          Process.kill('TERM', pid) # let's try to kill it
          logit["Tried to stop ##{pid} with SIGTERM (attempt no.#{attempt}, #{since.ago}): #{cmd}"]
          sleep(0.1)
          attempt += 1
        rescue Errno::ESRCH
          logit["Process ##{pid} reacted to SIGTERM, after #{attempt} attempts and #{since.ago}"] if attempt > 1
          break
        end
      else
        consume.call
      end
      e = ctrl.value.to_i
      if !accept.nil? && !accept.include?(e)
        raise "The command '#{cmd}' failed with exit code ##{e} in #{start.ago}\n#{buf}"
      end
    end
    return [buf, e] if both
    buf
  end
end
