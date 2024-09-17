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

First, install it:

```bash
gem install qbash
```

Simply execute a bash command from Ruby:

```ruby
require 'qbash'
stdout = qbash('echo "Hello, world!"')
```

If the command fails, an exception will be raised.

It's possible to provide the standard input and environment variables:

```ruby
stdout = qbash('cat > $FILE', env: { 'FILE' => 'a.txt' }, stdin: 'Hello!')
```

It's possible to configure the logging facility too, with the help
of the [loog](https://github.com/yegor256/loog) gem.

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

It is very much recommended to escape all command-line values with the help
of [Shellwords.escape][shellwords].

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
