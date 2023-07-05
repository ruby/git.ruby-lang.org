#!/usr/bin/env ruby

require 'uri'
require 'net/http'
require 'json'

log_path = ARGV[0]
log_contents = File.read(log_path).split("### start ###").last || ""

payload = {
  attachments: [{
    title: File.basename(log_path),
    text: log_contents,
  }]
}

URL = File.read(File.expand_path("~git/config/slack-webhook-alerts-sync")).chomp
uri = URI.parse(URL)
http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true
result = http.start do
  req = Net::HTTP::Post.new(uri.path)
  req.set_form_data(payload: payload.to_json)
  http.request(req)
end

puts "---"
puts "#{$0}: status #{result.code}"
