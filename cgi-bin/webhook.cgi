#!/usr/bin/env ruby
require 'cgi'

puts CGI.new.header
puts 'hello world'
