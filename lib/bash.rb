# frozen_string_literal: true

# Copyright (c) 2024 Yegor Bugayenko
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

require 'open3'
require 'loog'
require 'backtrace'

# Execute one bash command.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024 Yegor Bugayenko
# License:: MIT
module Kernel
  # Execute a single bash command.
  #
  # If exit code is not zero, an exception will be raised.
  #
  # To escape arguments, use +Shellwords.escape()+ method.
  #
  # @param [String] cmd The command to run
  # @param [String] stdin Input string
  # @param [Hash] env Environment variables
  # @param [Loog] loog Logging facility with +.debug()+ method
  # @return [String] Stdout
  def bash(cmd, stdin: '', env: {}, loog: Loog::NULL)
    loog.debug("+ #{cmd}")
    buf = ''
    Open3.popen2e(env, "/bin/bash -c #{Shellwords.escape(cmd)}") do |sin, sout, thr|
      sin.write(stdin)
      sin.close
      until sout.eof?
        begin
          ln = sout.gets
        rescue IOError => e
          ln = Backtrace.new(e).to_s
        end
        loog.debug(ln)
        buf += ln
      end
      e = thr.value.to_i
      raise "The command '#{cmd}' failed with exit code ##{e}\n#{buf}" unless e.zero?
    end
    buf
  end
end
