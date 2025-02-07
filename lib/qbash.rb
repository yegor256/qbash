# frozen_string_literal: true

# Copyright (c) 2024-2025 Yegor Bugayenko
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the 'Software'), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

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
  # Execute a single bash command.
  #
  # For example:
  #
  #  year = qbash('date +%Y')
  #
  # If exit code is not zero, an exception will be raised.
  #
  # To escape arguments, use +Shellwords.escape()+ method.
  #
  # Stderr automatically merges with stdout.
  #
  # If you need full control over the process started, provide
  # a block, which will receive process ID (integer) once the process
  # is started.
  #
  # Read this <a href="https://github.com/yegor256/qbash">README</a> file for more details.
  #
  # @param [String] cmd The command to run, for example +echo "Hello, world!"+
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
      log.__send__(mtd, "+ #{cmd}")
    else
      log.print("+ #{cmd}\n")
    end
    buf = ''
    e = 1
    start = Time.now
    Open3.popen2e(env, "/bin/bash -c #{Shellwords.escape(cmd)}") do |sin, sout, thr|
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
              ln = "##{thr.pid}: #{ln}"
              if log.nil?
                # no logging
              elsif log.respond_to?(mtd)
                log.__send__(mtd, ln)
              else
                log.print(ln)
              end
              buf += ln
            end
          end
        pid = thr.pid
        yield pid
        closed = true
        Process.kill('TERM', pid)
        watch.join
      else
        until sout.eof?
          begin
            ln = sout.gets
          rescue IOError => e
            ln = Backtrace.new(e).to_s
          end
          if log.nil?
            # no logging
          elsif log.respond_to?(mtd)
            log.__send__(mtd, ln)
          else
            log.print(ln)
          end
          buf += ln
        end
        e = thr.value.to_i
        if !accept.nil? && !accept.include?(e)
          raise "The command '#{cmd}' failed with exit code ##{e} in #{start.ago}\n#{buf}"
        end
      end
    end
    return [buf, e] if both
    buf
  end
end
