#!/usr/bin/env ruby

require "open3"

# This is the correspondence table between SVN_ACCOUNT_NAME and GIT_COMMITTER_EMAIL.
# SVN_ACCOUNT_NAME is set in ~git/.ssh/authorized_keys.
#
# You can add a new email address but DO NOT DELETE alread-registered email address.
# This association will be used for committer identification of the ruby repository.

SVN_TO_EMAILS = {
  "hsbt" => ["hsbt@ruby-lang.org"],
  "k0kubun" => ["takashikkbn@gmail.com"],
  "kazu" => ["zn@mbf.nifty.com"],
  "mame" => ["mame@ruby-lang.org"],
}

LOG_FILE = "/home/git/email.log"

svn_account_name = ENV["SVN_ACCOUNT_NAME"]
if svn_account_name.nil?
  puts "Failed to identify your ssh key."
  puts "Maybe ~git/.ssh/authorized_keys is broken."
  puts "Please contact on ruby-core@ruby-lang.org."
  exit 1
end

emails = SVN_TO_EMAILS[svn_account_name]

ARGV.each_slice(3) do |oldrev, newrev, refname|
  out, = Open3.capture2("git", "log", "--pretty=format:%H\n%ce", "-z", oldrev + ".." + newrev)

  out.split("\0").reverse_each do |s|
    hash, git_committer_email = s.split("\n")
    if emails
      if emails == git_committer_email || emails.include?(git_committer_email)
        # OK
      else
        puts "Your ssh key is not associated to the git committer email."
        puts "Please see https://github.com/ruby/ruby-commit-hook/blob/master/bin/check-email.rb"
        puts "and send PR, or contact on ruby-core@ruby-lang.org."
        exit 1 # NG
      end
    else
      if Time.now > Time.new(2020, 1, 1)
        puts "Your ssh key is unknown."
        puts "Please see https://github.com/ruby/ruby-commit-hook/blob/master/bin/check-email.rb"
        puts "and send PR, or contact on ruby-core@ruby-lang.org."
        exit 1 # NG
      else
        # Until the last of 2019, we record the association of SVN_ACCOUNT_NAME and GIT_COMMITTER_EMAIL.
        open(LOG_FILE, "a") do |f|
          f.puts "#{ hash } #{ svn_account_name } #{ git_committer_email }"
        end
      end
    end
  end
end
