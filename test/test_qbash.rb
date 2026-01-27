# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require 'minitest/autorun'
require 'securerandom'
require 'tmpdir'
require 'loog'
require 'logger'
require 'shellwords'
require_relative 'test__helper'
require_relative '../lib/qbash'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2026 Yegor Bugayenko
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

  def test_command_as_arguments
    assert_equal('123', qbash('printf 1;', 'printf 2;', 'printf', 3))
  end

  def test_log_to_console
    qbash('echo Hello world!', stdout: $stdout)
  end

  def test_logs_non_unicode
    qbash('printf "\xFF\xFE\x12"', stdout: $stdout)
  end

  def test_log_to_loog
    [Logger::DEBUG, Logger::INFO, Logger::WARN, Logger::ERROR].each do |level|
      qbash('echo Hello world!', stdout: Loog::NULL, level:)
    end
  end

  def test_skip_nil
    assert_equal('Hi!', qbash(['printf', nil, 'Hi!', '']))
  end

  def test_log_to_nil
    assert_equal("yes\n", qbash('echo yes', stdout: nil))
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
      qbash('sleep 767676', accept: nil, stdout: $stdout) do
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
          qbash(cmd, stdout: buf, accept: nil) do |pid|
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
    qbash('echo one; echo two', stdout: buf, accept: nil) do |i|
      sleep(0.1)
      pid = i
    end
    assert_equal(buf.to_s, "+ echo one; echo two /##{pid}\n##{pid}: one\n##{pid}: two\n")
  end

  def test_logs_multi_line_to_console
    console = FakeConsole.new
    pid = nil
    qbash('echo one; echo two', stdout: console, accept: nil) do |i|
      sleep(0.1)
      pid = i
    end
    assert_equal(console.to_s, "+ echo one; echo two /##{pid}\n##{pid}: one\n##{pid}: two\n")
  end

  def test_with_both_and_empty_stdout
    Dir.mktmpdir do |home|
      stdout, code = qbash("cat #{Shellwords.escape(File.join(home, 'foo.txt'))}", accept: nil, both: true)
      assert_predicate(code, :positive?)
      assert_empty(stdout)
    end
  end

  def test_exists_after_background_stop
    stop = false
    t =
      Thread.new do
        qbash('trap "" TERM; sleep 10', accept: nil) do
          loop { break if stop }
        end
      end
    t.abort_on_exception = true
    sleep(0.01)
    stop = true
    refute(t.join(0.1))
    t.kill
  end

  def test_success_exit_code
    [-512, -256, 0, 256, 512].each do |c|
      qbash("exit #{c}", accept: nil, both: true).then do |_, e|
        assert_predicate(e, :zero?)
      end
    end
  end

  def test_error_exit_code
    [-257, -255, -128, -2, -1, 1, 2, 128, 255, 257].each do |c|
      qbash("exit #{c}", accept: nil, both: true).then do |_, e|
        assert_equal(c % 256, e, "Incorrect process exit error code for `exit #{c}`")
      end
    end
  end

  def test_runs_command_in_specified_directory
    Dir.mktmpdir do |home|
      real = File.realpath(home)
      assert_equal("#{real}\n", qbash('pwd', chdir: home), "Command did not run in specified directory #{home}")
    end
  end

  def test_creates_file_in_specified_directory
    Dir.mktmpdir do |home|
      name = "файл-#{SecureRandom.hex(4)}.txt"
      qbash("echo test > #{Shellwords.escape(name)}", chdir: home)
      assert_path_exists(File.join(home, name), "File was not created in specified directory #{home}")
    end
  end

  def test_fails_when_chdir_directory_doesnt_exist
    missing = "/tmp/nonexistent-#{SecureRandom.hex(8)}"
    assert_raises(Errno::ENOENT, "Did not raise error for missing directory #{missing}") { qbash('pwd', chdir: missing) }
  end

  def test_chdir_works_with_env_variables
    Dir.mktmpdir do |home|
      marker = "marker-#{SecureRandom.hex(4)}"
      result = qbash('pwd; echo $MARKER', chdir: home, env: { 'MARKER' => marker })
      assert_includes(result, marker, 'Environment variable was not set when using chdir')
    end
  end

  def test_stderr_doesnt_go_to_stdout_by_default
    marker = "stderr-marker-#{SecureRandom.hex(4)}"
    result = qbash("echo #{marker} >&2", accept: nil)
    refute_includes(result, marker, 'Stderr was not captured in stdout by default')
  end

  def test_stderr_redirects_to_separate_logger
    marker = "отметка-#{SecureRandom.hex(4)}"
    buf = Loog::Buffer.new
    result = qbash("echo #{marker} >&2", stderr: buf, accept: nil)
    refute_includes(result, marker, 'Stderr should not appear in stdout when redirected')
    assert_includes(buf.to_s, marker, 'Stderr was not captured in separate logger')
  end

  def test_prints_error_to_stderr
    buf = Loog::Buffer.new
    qbash('cat /bad-file-name', stderr: buf, accept: nil)
    assert_includes(buf.to_s, 'No such file or directory')
  end

  def test_stderr_discarded_when_nil
    marker = "discard-#{SecureRandom.hex(4)}"
    result = qbash("echo stdout; echo #{marker} >&2", stderr: nil, accept: nil)
    refute_includes(result, marker, 'Stderr should be discarded when stderr is nil')
    assert_includes(result, 'stdout', 'Stdout should still be captured')
  end

  def test_stderr_with_both_streams_producing_output
    out = "out-#{SecureRandom.hex(4)}"
    err = "err-#{SecureRandom.hex(4)}"
    buf = Loog::Buffer.new
    result = qbash("echo #{out}; echo #{err} >&2", stderr: buf, accept: nil)
    assert_includes(result, out, 'Stdout was not captured')
    refute_includes(result, err, 'Stderr should not appear in stdout')
    assert_includes(buf.to_s, err, 'Stderr was not captured in separate logger')
  end

  def test_stderr_to_console
    console = FakeConsole.new
    marker = "console-#{SecureRandom.hex(4)}"
    qbash("echo #{marker} >&2", stderr: console, accept: nil)
    assert_includes(console.to_s, marker, 'Stderr was not printed to console')
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
