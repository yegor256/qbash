# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require 'English'

Gem::Specification.new do |s|
  s.required_rubygems_version = Gem::Requirement.new('>= 0') if s.respond_to? :required_rubygems_version=
  s.required_ruby_version = '>=3.2'
  s.name = 'qbash'
  s.version = '0.6.0'
  s.license = 'MIT'
  s.summary = 'Quick Executor of a BASH Command'
  s.description =
    'With the help of Open3 executes bash command and conveniently ' \
    'returns its output and exit code'
  s.authors = ['Yegor Bugayenko']
  s.email = 'yegor256@gmail.com'
  s.homepage = 'https://github.com/yegor256/qbash'
  s.files = `git ls-files | grep -v -E '^(test/|\\.|renovate)'`.split($RS)
  s.executables = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.rdoc_options = ['--charset=UTF-8']
  s.extra_rdoc_files = ['README.md', 'LICENSE.txt']
  s.add_dependency 'backtrace', '>0'
  s.add_dependency 'elapsed', '>0'
  s.add_dependency 'loog', '>0'
  s.add_dependency 'tago', '>0'
  s.metadata['rubygems_mfa_required'] = 'true'
end
