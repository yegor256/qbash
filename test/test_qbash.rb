# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require 'minitest/autorun'
require 'tmpdir'
require 'loog'
require 'logger'
require 'shellwords'
require_relative 'test__helper'
require_relative '../lib/qbash'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2025 Yegor Bugayenko
# License:: MIT
class TestQbash < Minitest::Test
  def test_basic_run
    Dir.mktmpdir do |home|
      qbash("cd #{Shellwords.escape(home)}; echo $FOO | cat > a.txt", env: { 'FOO' => '42' })
      assert_path_exists(File.join(home, 'a.txt'))
      assert_equal("42\n", File.read(File.join(home, 'a.txt')))
    end
  end

  def test_command_as_array
    assert_equal('123', qbash(['printf 1;', 'printf 2;', 'printf', 3]))
  end

  def test_log_to_console
    qbash('echo Hello world!', log: $stdout)
  end

  def test_log_to_loog
    [Logger::DEBUG, Logger::INFO, Logger::WARN, Logger::ERROR].each do |level|
      qbash('echo Hello world!', log: Loog::NULL, level:)
    end
  end

  def test_skip_nil
    assert_equal('Hi!', qbash(['printf', nil, 'Hi!', '']))
  end

  def test_log_to_nil
    assert_equal("yes\n", qbash('echo yes', log: nil))
  end

  def test_accept_zero
    qbash('echo hi', accept: nil)
  end

  def test_with_stdin
    Dir.mktmpdir do |home|
      f = File.join(home, 'a b c.txt')
      qbash("cat > #{Shellwords.escape(f)}", stdin: 'hello')
      assert_path_exists(f)
      assert_equal('hello', File.read(f))
    end
  end

  def test_with_special_symbols
    assert_equal("'hi'\n", qbash("echo \"'hi'\""))
  end

  def test_with_error
    Dir.mktmpdir do |home|
      assert_raises(StandardError) { qbash("cat #{Shellwords.escape(File.join(home, 'b.txt'))}") }
    end
  end

  def test_fails_when_nil_env
    assert_raises(StandardError) { qbash('echo hi', env: { a: nil }) }
  end

  def test_ignore_errors
    Dir.mktmpdir do |home|
      qbash("cat #{Shellwords.escape(File.join(home, 'b.txt'))}", accept: nil)
    end
  end

  def test_kills_in_thread
    Thread.new do
      qbash('sleep 9999') do |pid|
        Process.kill('KILL', pid)
      end
    end.join
  end

  def test_logs_in_background
    stdout = nil
    buf = Loog::Buffer.new
    Dir.mktmpdir do |home|
      flag = File.join(home, 'started.txt')
      Thread.new do
        stdout =
          qbash("while true; do date; touch #{Shellwords.escape(flag)}; sleep 0.001; done", log: buf) do |pid|
            loop { break if File.exist?(flag) }
            Process.kill('KILL', pid)
          end
      end.join
    end
    refute_empty(buf.to_s)
    refute_empty(stdout)
    refute_includes(stdout, "\n\n")
    refute_includes(buf.to_s, "\n\n")
  end

  def test_with_both
    Dir.mktmpdir do |home|
      stdout, code = qbash("cat #{Shellwords.escape(File.join(home, 'foo.txt'))}", accept: nil, both: true)
      assert_predicate(code, :positive?)
      refute_empty(stdout)
    end
  end

  def test_exists_after_background_stop
    stop = false
    t =
      Thread.new do
        qbash('tail -f /dev/null') do
          loop { break if stop }
        end
      end
    sleep(0.1)
    stop = true
    t.join
    refute_predicate(t, :alive?)
  end
end
