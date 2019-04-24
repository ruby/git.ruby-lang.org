#!/usr/bin/env ruby

require "net/https"
require "open3"
require "json"

SLACK_WEBHOOK_URLS = [
  File.read(File.expand_path("~git/config/slack-webhook-alerts")).chomp,
  File.read(File.expand_path("~git/config/slack-webhook-commits")).chomp,
]

def escape(s)
  s.gsub(/[&<>]/, "&" => "&amp;", "<" => "&lt;", ">" => "&gt;")
end

ARGV.each_slice(3) do |oldrev, newrev, refname|
  out, = Open3.capture2("git", "rev-parse", "--symbolic", "--abbrev-ref", refname)
  branch = out.strip

  out, = Open3.capture2("git", "log", "--pretty=format:%H\n%h\n%an\n%at\n%cn\n%ct\n%B", "--abbrev=10", "-z", oldrev + ".." + newrev)

  attachments = []
  out.split("\0").reverse_each do |s|
    hash, abbr_hash, _author, _authortime, committer, committertime, body = s.split("\n", 7)
    subject, body = body.split("\n", 2)
    body = body.strip.sub(%r(git-svn-id: svn\+ssh://ci\.ruby-lang\.org/ruby/trunk@(\d+) \h+-\h+-\h+-\h+-\h+\z)) { "(r#$1)" }.strip
    attachments << {
      title: "#{ abbr_hash } (#{ branch }): #{ escape(subject) }",
      title_link: "https://github.com/ruby/ruby/commit/" + hash,
      text: escape((body || "").strip),
      footer: committer,
      ts: committertime.to_i,
    }
  end

  json = { attachments: attachments }

  #Net::HTTP.post(
  #  URI.parse(SLACK_WEBHOOK_URL),
  #  JSON.generate(json),
  #  "Content-Type" => "application/json"
  #)
  SLACK_WEBHOOK_URLS.each do |url|
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.start do
      req = Net::HTTP::Post.new(uri.path)
      req.set_form_data(payload: json.to_json)
      http.request(req)
    end
  end
end
