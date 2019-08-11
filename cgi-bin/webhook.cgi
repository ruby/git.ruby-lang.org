#!/usr/bin/env ruby
require 'cgi'
require 'logger'

cgi = CGI.new

logger = Logger.new('/tmp/webhook.log')
logger.info(Time.now.to_s)
cgi.keys.each do |key|
  logger.info("#{key}: #{cgi[key]}")
end

print cgi.header
print "OK\r\n"
