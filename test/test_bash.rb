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

require 'minitest/autorun'
require 'tmpdir'
require 'loog'
require 'shellwords'
require_relative 'test__helper'
require_relative '../lib/bash'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024 Yegor Bugayenko
# License:: MIT
class TestJudge < Minitest::Test
  def test_basic_run
    Dir.mktmpdir do |home|
      bash("cd #{Shellwords.escape(home)}; echo $FOO | cat > a.txt", env: { 'FOO' => '42' })
      assert(File.exist?(File.join(home, 'a.txt')))
      assert_equal("42\n", File.read(File.join(home, 'a.txt')))
    end
  end

  def test_with_stdin
    Dir.mktmpdir do |home|
      f = File.join(home, 'a b c.txt')
      bash("cat > #{Shellwords.escape(f)}", stdin: 'hello')
      assert(File.exist?(f))
      assert_equal('hello', File.read(f))
    end
  end

  def test_with_special_symbols
    assert_equal("'hi'\n", bash("echo \"'hi'\""))
  end

  def test_with_error
    Dir.mktmpdir do |home|
      assert_raises { bash("cat #{Shellwords.escape(File.join(home, 'b.txt'))}") }
    end
  end

  def test_ignore_errors
    Dir.mktmpdir do |home|
      bash("cat #{Shellwords.escape(File.join(home, 'b.txt'))}", accept: [])
    end
  end
end
