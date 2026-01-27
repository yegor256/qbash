# Quick and Simple Executor of Bash Commands

[![DevOps By Rultor.com](https://www.rultor.com/b/yegor256/qbash)](https://www.rultor.com/p/yegor256/qbash)
[![We recommend RubyMine](https://www.elegantobjects.org/rubymine.svg)](https://www.jetbrains.com/ruby/)

[![rake](https://github.com/yegor256/qbash/actions/workflows/rake.yml/badge.svg)](https://github.com/yegor256/qbash/actions/workflows/rake.yml)
[![PDD status](https://www.0pdd.com/svg?name=yegor256/qbash)](https://www.0pdd.com/p?name=yegor256/qbash)
[![Gem Version](https://badge.fury.io/rb/qbash.svg)](https://badge.fury.io/rb/qbash)
[![Test Coverage](https://img.shields.io/codecov/c/github/yegor256/qbash.svg)](https://codecov.io/github/yegor256/qbash?branch=master)
[![Yard Docs](https://img.shields.io/badge/yard-docs-blue.svg)](https://rubydoc.info/github/yegor256/qbash/master/frames)
[![Hits-of-Code](https://hitsofcode.com/github/yegor256/qbash)](https://hitsofcode.com/view/github/yegor256/qbash)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](https://github.com/yegor256/qbash/blob/master/LICENSE.txt)

How do you execute a new shell command from Ruby?
There are [many ways][so-question].
None of them offers a one-liner that would execute a command,
  print its output to the console or a logger, and then raise an exception if
  the exit code is not zero.
This small gem offers exactly this one-liner.

First, install it:

```bash
gem install qbash
```

Then, you can use [qbash] global function:

```ruby
require 'qbash'
stdout = qbash('echo "Hello, world!"', log: $stdout)
```

If the command fails, an exception is raised.

By default, `stderr` merges with the `stdout` logger.
You can redirect it elsewhere:

```ruby
# Redirect stderr to a separate logger
err = Loog::Buffer.new
qbash('cmd', stderr: err)

# Discard stderr completely
qbash('cmd', stderr: nil)
```

It's possible to provide the standard input and environment variables:

```ruby
stdout = qbash('cat > $FILE', env: { 'FILE' => 'a.txt' }, stdin: 'Hello!')
```

It's possible to configure the logging facility too, for example,
  with the help of the [loog] gem
  (the output is returned _and_ printed to the logger):

```ruby
require 'loog'
qbash('echo "Hello, world!"', log: Loog::VERBOSE)
```

You can also make it return both stdout and exit code,
  with the help of the `both` option set to `true`:

```ruby
stdout, code = qbash('cat a.txt', both: true, accept: [])
```

Here, the `accept` param contains the list of exit codes that are "acceptable"
  and won't lead to runtime failures.
When the list is empty, all exits are acceptable (no failures occur).

The command may be provided as an array, which is automatically
  converted to a string by joining all items with spaces between them.

```ruby
qbash(
  [
    'echo "Hello, world!"',
    '&& echo "How are you?"',
    '&& cat /etc/passwd'
  ]
)
```

Even simpler:

```ruby
qbash(
  'echo "Hello, world!"',
  '&& echo "How are you?"',
  '&& cat /etc/passwd'
)
```

If a block is given to `qbash`, it runs the command in background mode,
  waiting for the block to finish.
Once finished, the command is terminated via the `TERM` [signal]:

```ruby
qbash('sleep 9999') do |pid|
  # do something
end
```

It is very much recommended to escape all command-line values with the help
  of the [Shellwords.escape()][shellwords] utility method, for example:

```ruby
file = '/tmp/test.txt'
qbash("cat #{Shellwords.escape(file)}")
```

Without such escaping, a space inside the `file` variable
  leads to an unpredictable result.

If you want to stop sooner than the command finishes, use [timeout] gem:

```ruby
require 'timeout'
Timeout.timeout(5) do
  qbash('sleep 100')
end
```

This raises a `Timeout::Error` exception after five seconds
  of waiting for `sleep` to finish.

## How to contribute

Read [these guidelines][guidelines].
Make sure your build is green before you contribute your pull request.
You need [Ruby] 3.0+ and [Bundler] installed.
Then:

```bash
bundle update
bundle exec rake
```

If it's clean and you don't see any error messages, submit your pull request.

[Bundler]: https://bundler.io/
[guidelines]: https://www.yegor256.com/2014/04/15/github-guidelines.html
[loog]: https://github.com/yegor256/loog
[qbash]: https://rubydoc.info/github/yegor256/qbash/master/Kernel#qbash-instance_method
[Ruby]: https://www.ruby-lang.org/en/
[shellwords]: https://ruby-doc.org/stdlib-3.0.1/libdoc/shellwords/rdoc/Shellwords.html
[signal]: https://en.wikipedia.org/wiki/Signal_(IPC)
[so-question]: https://stackoverflow.com/questions/2232/
[timeout]: https://github.com/ruby/timeout
