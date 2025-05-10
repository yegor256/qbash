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
  # @param [Hash] env Hash of environment variables
  # @param [Loog|IO] log Logging facility with +.debug()+ method (or +$stdout+, or nil if should go to +/dev/null+)
  # @param [Array] accept List of accepted exit codes (accepts all if the list is +nil+)
  # @param [Boolean] both If set to TRUE, the function returns an array +(stdout, code)+
  # @param [Integer] level Logging level (use +Logger::DEBUG+, +Logger::INFO+, +Logger::WARN+, or +Logger::ERROR+)
  # @return [String] Everything that was printed to the +stdout+ by the command
  def qbash(cmd, stdin: '', env: {}, log: Loog::NULL, accept: [0], both: false, level: Logger::DEBUG)
    env.each { |k, v| raise "env[#{k}] is nil" if v.nil? }
    cmd = cmd.reject { |a| a.nil? || (a.is_a?(String) && a.empty?) }.join(' ') if cmd.is_a?(Array)
    logit =
      lambda do |msg|
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
    logit["+ #{cmd}"]
    buf = ''
    e = 1
    start = Time.now
    Open3.popen2e(env, "/bin/bash -c #{Shellwords.escape(cmd)}") do |sin, sout, ctrl|
      sin.write(stdin)
      sin.close
      if block_given?
        closed = false
        watch =
          Thread.new do
            until closed
              begin
                ln = sout.gets
              rescue IOError => e
                ln = Backtrace.new(e).to_s
              end
              next if ln.nil?
              next if ln.empty?
              ln = "##{ctrl.pid}: #{ln}"
              logit[ln]
              buf += ln
            end
          end
        pid = ctrl.pid
        yield pid
        begin
          Process.kill('TERM', pid)
        rescue Errno::ESRCH => e
          logit[e.message]
        end
        closed = true
        watch.join
      else
        until sout.eof?
          begin
            ln = sout.gets
          rescue IOError => e
            ln = Backtrace.new(e).to_s
          end
          next if ln.nil?
          next if ln.empty?
          logit[ln]
          buf += ln
        end
        e = ctrl.value.to_i
        if !accept.nil? && !accept.include?(e)
          raise "The command '#{cmd}' failed with exit code ##{e} in #{start.ago}\n#{buf}"
        end
      end
    end
    return [buf, e] if both
    buf
  end
end
