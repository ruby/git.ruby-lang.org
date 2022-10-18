#!/usr/bin/env ruby
# This is executed by `/etc/systemd/system/git-sync-check.service` as User=git
# which is triggered every 10 minutes by `/etc/systemd/system/git-sync-check.timer`.

require 'json'
require 'net/http'
require 'uri'

module Git
  # cgit bare repository
  GIT_DIR = '/var/git/ruby.git'

  # This is retried because ls-remote of GitHub sometimes fails
  Error = Class.new(StandardError)

  class << self
    def show_ref
      git('show-ref')
    end

    def ls_remote(remote)
      git('ls-remote', remote)
    end

    private

    def git(*cmd)
      out = IO.popen({ 'GIT_DIR' => GIT_DIR }, ['git', *cmd], &:read)
      unless $?.success?
        raise Git::Error.new("Failed to execute: git #{cmd.join(' ')}")
      end
      out
    end
  end
end

module Slack
  WEBHOOK_URL = File.read(File.expand_path('~git/config/slack-webhook-alerts')).chomp
  NOTIFY_CHANNELS = [
    "C5FCXFXDZ", # alerts
    "CR2QGFCAE", # alerts-emoji
  ]

  class << self
    def notify(message)
      attachment = {
        title: 'bin/git-sync-check.rb',
        title_link: 'https://github.com/ruby/git.ruby-lang.org/blob/master/bin/git-sync-check.rb',
        text: message,
        color: 'danger',
      }

      payload = { username: 'ruby/git.ruby-lang.org', attachments: [attachment] }
      NOTIFY_CHANNELS.each do |channel|
        resp = post(WEBHOOK_URL, payload: payload.merge(channel: channel))
        puts "#{resp.code} (#{resp.body}) -- #{payload.to_json} (channel: #{channel})"
      end
    end

    private

    def post(url, payload:)
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == 'https')
      http.start do
        req = Net::HTTP::Post.new(uri.path)
        req.set_form_data({ payload: payload.to_json })
        http.request(req)
      end
    end
  end
end

module GitSyncCheck
  class Errors < StandardError
    attr_reader :errors

    def initialize(errors)
      @errors = errors
      super('git-sync-check failed')
    end
  end

  def self.check_consistency
    # Quickly finish collecting facts to avoid a race condition as much as possible.
    ls_remote = Git.ls_remote('github')
    show_ref  = Git.show_ref

    # Start digesting the data after the collection.
    remote_refs = Hash[ls_remote.lines.map { |l| rev, ref = l.chomp.split("\t"); [ref, rev] }]
    local_refs  = Hash[show_ref.lines.map  { |l| rev, ref = l.chomp.split(' ');  [ref, rev] }]

    # Remove refs which are not to be checked here.
    remote_refs.delete('HEAD') # show-ref does not show it
    remote_refs.keys.each { |ref| remote_refs.delete(ref) if ref.match(%r[\Arefs/pull/\d+/\w+\z]) } # pull requests

    # Check consistency
    errors = {}
    (remote_refs.keys | local_refs.keys).each do |ref|
      remote_rev = remote_refs[ref]
      local_rev  = local_refs[ref]

      if remote_rev != local_rev
        errors[ref] = [remote_rev, local_rev]
      end
    end

    unless errors.empty?
      raise Errors.new(errors)
    end
  end
end

attempts = 3
begin
  GitSyncCheck.check_consistency
  puts 'SUCCUESS: Everything is consistent.'
rescue GitSyncCheck::Errors => e
  attempts -= 1
  if attempts > 0
    # Automatically fix inconsistency if it's master, but never sync random new branches.
    if e.errors.key?('refs/heads/master')
      remote_ref, local_rev = e.errors['refs/heads/master']
      puts "Fixing inconsistency ref:#{ref.inspect} remote:#{remote_rev.inspect} local:#{local_rev.inspect}"
      unless system('/home/git/git.ruby-lang.org/bin/update-ruby.sh', File.basename(ref))
        raise "Failed to execute update-ruby.sh for #{ref}"
      end
    end
    sleep 5
    retry
  end

  message = "FAILURE: Following inconsistencies are found.\n"
  e.errors.each do |ref, (remote_rev, local_rev)|
    message << "ref:#{ref.inspect} remote:#{remote_rev.inspect} local:#{local_rev.inspect}\n"
  end
  # Slack.notify(message)
  puts message
rescue Git::Error => e
  attempts -= 1
  if attempts > 0
    puts "Retrying #{e.class}: #{e.message} (remaining attempts: #{attempts})"
    sleep 5
    retry
  end
  Slack.notify("#{e.class}: #{e.message}\n#{e.backtrace.join("\n")}")
rescue => e
  Slack.notify("#{e.class}: #{e.message}\n#{e.backtrace.join("\n")}")
end
