#!/usr/bin/env ruby
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

    logger.info(Time.now.to_s)
    return true
  end

  private

  # See:
  # https://developer.github.com/webhooks/
  # https://developer.github.com/webhooks/securing/
  def authorized_webhook?
    return false if @payload.nil? || @signature.nil? || @secret.nil?
    logger.info("sig: #{@signature}")
    logger.info("ans: sha1=#{OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), @secret, @payload)}")
    @signature == "sha1=#{OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), @secret, @payload)}"
  end

  def logger
    @logger ||= Logger.new(LOG_PATH)
  end
end

cgi = CGI.new
print cgi.header
begin
  webhook = Webhook.new(
    payload: cgi['payload'],
    signature: ENV['HTTP_X_HUB_SIGNATURE'],
    secret: 'helloworld', # don't worry, this will be changed later
  )
  print "#{webhook.process}\r\n"
rescue => e
  puts "#{e.class}: #{e.message}"
  puts e.backtrace
end
