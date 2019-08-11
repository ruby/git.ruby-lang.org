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

    logger.info('Authorization success!')
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
    @signature == "sha1=#{OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), @secret, @payload)}"
  end

  def logger
    @logger ||= Logger.new(LOG_PATH)
  end
end

webhook = Webhook.new(
  payload: STDIN.read, # must be done before CGI.new
  signature: ENV['HTTP_X_HUB_SIGNATURE'],
  secret: 'helloworld', # don't worry, this will be changed later
)
print CGI.new.header
print "#{webhook.process}\r\n"
