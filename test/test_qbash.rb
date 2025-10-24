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

  def test_lets_exception_float_up
    assert_raises(StandardError) do
      qbash('sleep 767676', accept: nil, log: $stdout) do
        raise 'intentional'
      end
    end
  end

  def test_kills_in_thread
    Thread.new do
      qbash('sleep 9999', accept: nil) do |pid|
        Process.kill('KILL', pid)
      end
    end.join
  end

  def test_truly_kills
    qbash('sleep 9876543', accept: nil) do
      sleep(0.1)
    end
    refute_empty(qbash('ps ax | grep -v 9876543'))
  end

  def test_executes_without_sh_only_bash
    qbash('sleep 89898989', accept: nil) do
      refute_empty(qbash('ps ax | grep -v "sh -c exec /bin/bash -c sleep 89898989" | grep -v grep'))
      refute_empty(qbash('ps ax | grep "sleep 89898989" | grep -v grep'))
      sleep(0.1)
    end
  end

  def test_logs_in_background
    stdout = nil
    buf = Loog::Buffer.new
    Dir.mktmpdir do |home|
      flag = File.join(home, 'started.txt')
      cmd = "while true; do date; touch #{Shellwords.escape(flag)}; sleep 0.001; done"
      Thread.new do
        stdout =
          qbash(cmd, log: buf, accept: nil) do |pid|
            start = Time.now
            loop do
              break if File.exist?(flag)
              raise 'Timeout waiting for flag file' if Time.now - start > 5
              sleep 0.01
            end
            Process.kill('KILL', pid)
          end
      end.join
    end
    refute_empty(buf.to_s)
    refute_empty(stdout)
    refute_includes(stdout, "\n\n")
    refute_includes(buf.to_s, "\n\n")
  end

  def test_logs_multi_line_print
    buf = Loog::Buffer.new
    pid = nil
    qbash('echo one; echo two', log: buf, accept: nil) do |i|
      sleep(0.1)
      pid = i
    end
    assert_equal(buf.to_s, "+ echo one; echo two /##{pid}\n##{pid}: one\n##{pid}: two\n")
  end

  def test_logs_multi_line_to_console
    console = FakeConsole.new
    pid = nil
    qbash('echo one; echo two', log: console, accept: nil) do |i|
      sleep(0.1)
      pid = i
    end
    assert_equal(console.to_s, "+ echo one; echo two /##{pid}\n##{pid}: one\n##{pid}: two\n")
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
    pid = nil
    t =
      Thread.new do
        qbash('trap "" TERM; sleep 10', accept: nil) do |id|
          pid = id
          loop { break if stop }
        end
      end
    t.abort_on_exception = true
    sleep(0.01)
    stop = true
    refute(t.join(0.1))
    t.kill
  end

  class FakeConsole
    def initialize
      @buf = ''
    end

    def to_s
      @buf
    end

    def print(ln)
      @buf += ln
    end
  end
end
