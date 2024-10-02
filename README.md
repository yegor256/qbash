# Quick and Simple Executor of Bash Commands

[![DevOps By Rultor.com](http://www.rultor.com/b/yegor256/qbash)](http://www.rultor.com/p/yegor256/qbash)
[![We recommend RubyMine](https://www.elegantobjects.org/rubymine.svg)](https://www.jetbrains.com/ruby/)

[![rake](https://github.com/yegor256/qbash/actions/workflows/rake.yml/badge.svg)](https://github.com/yegor256/qbash/actions/workflows/rake.yml)
[![PDD status](http://www.0pdd.com/svg?name=yegor256/qbash)](http://www.0pdd.com/p?name=yegor256/qbash)
[![Gem Version](https://badge.fury.io/rb/qbash.svg)](http://badge.fury.io/rb/qbash)
[![Test Coverage](https://img.shields.io/codecov/c/github/yegor256/qbash.svg)](https://codecov.io/github/yegor256/qbash?branch=master)
[![Yard Docs](http://img.shields.io/badge/yard-docs-blue.svg)](http://rubydoc.info/github/yegor256/qbash/master/frames)
[![Hits-of-Code](https://hitsofcode.com/github/yegor256/qbash)](https://hitsofcode.com/view/github/yegor256/qbash)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](https://github.com/yegor256/qbash/blob/master/LICENSE.txt)

How do you execute a new shell command from Ruby?
There are [many ways](https://stackoverflow.com/questions/2232).
None of them offers a one-liner that would execute a command, print
its output to the console or a logger, and then raise an exception if
the exit code is not zero. This small gem offers exactly this one-liner.

First, install it:

```bash
gem install qbash
```

Then, you can use [qbash][qbash] global function:

```ruby
require 'qbash'
stdout = qbash('echo "Hello, world!"', log: $stdout)
```

If the command fails, an exception will be raised.

The function automatically merges `stderr` with `stdout`
(you can't change this).

It's possible to provide the standard input and environment variables:

```ruby
stdout = qbash('cat > $FILE', env: { 'FILE' => 'a.txt' }, stdin: 'Hello!')
```

It's possible to configure the logging facility too, for example, with the help
of the [loog](https://github.com/yegor256/loog) gem (the output
will be returned _and_ printed to the logger):

```ruby
require 'loog'
qbash('echo "Hello, world!"', log: Loog::VERBOSE)
```

You can also make it return both stdout and exit code, with the help
of the `both` option set to `true`:

```ruby
stdout, code = qbash('cat a.txt', both: true, accept: [])
```

Here, the `accept` param contains the list of exit codes that are "acceptable"
and won't lead to runtime failures. When the list is empty, all exists are
acceptable (there will be no failures ever).

The command may be provided as an array, which automatically will be
converted to a string by joining all items with spaces between them.

```ruby
qbash(
  [
    'echo "Hello, world!"'
    '&& echo "How are you?"',
    '&& cat /etc/passwd'
  ]
)
```

It is very much recommended to escape all command-line values with the help
of the [Shellwords.escape()][shellwords] utility method, for example:

```ruby
file = '/tmp/test.txt'
qbash("cat #{Shellwords.escape(file)}")
```

Without such an escaping, in this example, a space inside the `file`
will lead to an unpredicatable result of the execution.

You can also set the maximum time for the command:

```ruby
qbash("sleep 100", timeout: 4)
```

This command will raise exception after four seconds.

## How to contribute

Read
[these guidelines](https://www.yegor256.com/2014/04/15/github-guidelines.html).
Make sure you build is green before you contribute
your pull request. You will need to have
[Ruby](https://www.ruby-lang.org/en/) 3.0+ and
[Bundler](https://bundler.io/) installed. Then:

```bash
bundle update
bundle exec rake
```

If it's clean and you don't see any error messages, submit your pull request.

[shellwords]: https://ruby-doc.org/stdlib-3.0.1/libdoc/shellwords/rdoc/Shellwords.html
[qbash]: https://rubydoc.info/github/yegor256/qbash/master/Kernel#qbash-instance_method
