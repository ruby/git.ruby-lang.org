#!/usr/bin/env ruby

require "net/https"
require "open3"
require "json"

SLACK_WEBHOOK_URL = File.read("/home/git/config/slack-webhook").chomp

ARGV.each_slice(3) do |oldrev, newrev, refname|
  out, = Open3.capture2("git", "log", "--pretty=format:%H\n%h\n%an\n%at\n%cn\n%ct\n%B", "-z", ARGV[0] + ".." + ARGV[1])
  attachments = []
  out.split("\0").reverse_each do |s|
    hash, abbr_hash, _author, _authortime, committer, committertime, body = s.split("\n", 7)
    subject, body = body.split("\n", 2)
    attachments << {
      title: "#{ abbr_hash } (#{ refname }): #{ subject }",
      title_link: "https://github.com/ruby/ruby/commit/" + hash,
      text: (body || "").strip,
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
  uri = URI.parse(SLACK_WEBHOOK_URL)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.start do
    req = Net::HTTP::Post.new(uri.path)
    req.set_form_data(payload: json.to_json)
    http.request(req)
  end
end
