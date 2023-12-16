#!/usr/bin/env ruby
# This file is deployed as CGI on `https://git.ruby-lang.org/webhook`.
# See `sites-available/git.ruby-lang.org.conf`.

require 'cgi'
require 'json'
require 'logger'
require 'openssl'

class Webhook
  LOG_PATH = '/tmp/webhook.log'

  def initialize(payload:, signature:, secret:)
    @payload = payload
    @signature = signature
    @secret = secret
  end

  def process
    unless authorized_webhook?
      logger.info('Request was not an authorized webhook')
      return false
    end
    logger.info('Authorization succeeded!')

    payload = JSON.parse(@payload)
    repository = payload.fetch('repository').fetch('full_name')
    ref = payload.fetch('ref')
    before = payload.fetch('before')
    after  = payload.fetch('after')
    pusher = payload.fetch('pusher').fetch('name')

    PushHook.new(logger: logger).process(
      repository: repository,
      ref: ref,
      before: before,
      after: after,
      pusher: pusher,
    )
    return true
  rescue => e
    logger.info("#{e.class}: #{e.message}")
    logger.info(e.backtrace.join("\n"))
    return false
  end

  private

  # See:
  # https://developer.github.com/webhooks/
  # https://developer.github.com/webhooks/securing/
  def authorized_webhook?
    return false if @payload.nil? || @signature.nil? || @secret.nil?

    signature = "sha1=#{OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), @secret, @payload)}"
    Rack::Utils.secure_compare(@signature, signature)
  end

  def logger
    @logger ||= Logger.new(LOG_PATH)
  end
end

class PushHook
  DEFAULT_GEM_REPOS = %w[
    abbrev
    base64
    benchmark
    bigdecimal
    cgi
    date
    delegate
    did_you_mean
    digest
    drb
    English
    erb
    error_highlight
    etc
    fcntl
    fileutils
    find
    forwardable
    getoptlong
    io-console
    io-nonblock
    io-wait
    ipaddr
    irb
    logger
    mutex_m
    net-http
    net-protocol
    nkf
    observer
    open-uri
    open3
    openssl
    optparse
    ostruct
    pathname
    pp
    prettyprint
    prism
    pstore
    psych
    rdoc
    readline
    readline-ext
    reline
    resolv
    rinda
    securerandom
    set
    shellwords
    singleton
    stringio
    syntax_suggest
    syslog
    tempfile
    time
    timeout
    tmpdir
    tsort
    un
    uri
    weakref
    win32ole
    yaml
    zlib
  ].map { |repo| "ruby/#{repo}" } + %w[
    rubygems/rubygems
  ]
  # Set false to stop sync before a release
  DEFAULT_GEM_SYNC_ENABLED = false

  def initialize(logger:)
    @logger = logger
  end

  def process(repository:, ref:, before:, after:, pusher:)
    case repository
    when 'ruby/git.ruby-lang.org'
      on_push_git_ruby_lang_org(ref)
    when 'ruby/ruby'
      on_push_ruby(ref, pusher: pusher)
    when *DEFAULT_GEM_REPOS
      on_push_default_gem(ref, repository: repository, before: before, after: after)
    else
      logger.info("unexpected repository: #{repository}")
    end
  end

  private

  attr_reader :logger

  def on_push_git_ruby_lang_org(ref)
    if ref == 'refs/heads/master'
      # www-data user is allowed to sudo `/home/git/git.ruby-lang.org/bin/update-git-ruby-lang-org.sh`.
      execute('/home/git/git.ruby-lang.org/bin/update-git-ruby-lang-org.sh', user: 'git')
    else
      logger.info("skipped git.ruby-lang.org ref: #{ref}")
    end
  end

  def on_push_ruby(ref, pusher:)
    # Allow to sync like ruby_3_0, ruby_3_1, and master branches.
    if (ref == "refs/heads/master" || ref =~ /refs\/heads\/ruby_\d_\d/) && pusher != 'matzbot' # matzbot should stop an infinite loop here.
      # www-data user is allowed to sudo `/home/git/git.ruby-lang.org/bin/update-ruby.sh`.
      execute('/home/git/git.ruby-lang.org/bin/update-ruby.sh', File.basename(ref), user: 'git')
    else
      logger.info("skipped ruby ref: #{ref} (pusher: #{pusher})")
    end
  end

  def on_push_default_gem(ref, repository:, before:, after:)
    if ['refs/heads/master', 'refs/heads/main'].include?(ref) && DEFAULT_GEM_SYNC_ENABLED
      # www-data user is allowed to sudo `/home/git/git.ruby-lang.org/bin/update-default-gem.sh`.
      execute('/home/git/git.ruby-lang.org/bin/update-default-gem.sh', *repository.split('/', 2), before, after, user: 'git')
    else
      logger.info("skipped #{repository} ref: #{ref}")
    end
  end

  def execute(*cmd, user:)
    require 'open3'
    stdout, stderr, status = Open3.capture3('/usr/bin/sudo', '-u', user, *cmd)
    logger.info("+ #{cmd.join(' ')} (success: #{status.success?})")
    logger.info("stdout: #{stdout}")
    logger.info("stderr: #{stderr}")
  end
end

# The following `Rack::Util.secure_compare` is copied from:
# https://github.com/rack/rack/blob/2.0.7/lib/rack/utils.rb
=begin
The MIT License (MIT)

Copyright (C) 2007-2019 Leah Neukirchen <http://leahneukirchen.org/infopage.html>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to
deal in the Software without restriction, including without limitation the
rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
sell copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
=end
module Rack
  module Utils
    # Constant time string comparison.
    #
    # NOTE: the values compared should be of fixed length, such as strings
    # that have already been processed by HMAC. This should not be used
    # on variable length plaintext strings because it could leak length info
    # via timing attacks.
    def secure_compare(a, b)
      return false unless a.bytesize == b.bytesize

      l = a.unpack("C*")

      r, i = 0, -1
      b.each_byte { |v| r |= v ^ l[i+=1] }
      r == 0
    end
    module_function :secure_compare
  end
end

webhook = Webhook.new(
  payload: STDIN.read, # must be done before CGI.new
  signature: ENV['HTTP_X_HUB_SIGNATURE'],
  secret: File.read(File.expand_path('~git/config/git-ruby-lang-org-secret')).chomp,
)
print CGI.new.header
print "#{webhook.process}\r\n"
