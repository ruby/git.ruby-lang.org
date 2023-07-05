require 'uri'
require 'net/http'
require 'json'

log_contents = File.read(ARGV[0]).split("### start ###").last

payload = {
  attachments: [{
    text: (log_contents || "")
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

puts result.code
