#!/usr/bin/env ruby
require 'cgi'
require 'json'
require 'logger'
require 'pp'

cgi = CGI.new

logger = Logger.new('/tmp/webhook.log')
logger.info(Time.now.to_s)

#payload = JSON.parse(cgi['payload'])
logger.info(ENV.inspect)

print cgi.header
print "OK\r\n"
