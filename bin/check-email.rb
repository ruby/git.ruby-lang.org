#!/usr/bin/env ruby

# This is the correspondence table between SVN_ACCOUNT_NAME and GIT_COMMITTER_EMAIL.
# SVN_ACCOUNT_NAME is set in ~git/.ssh/authorized_keys.

SVN_TO_EMAILS = {
  "mame" => ["mame@ruby-lang.org"],
}

svn_account_name = ARGV[0]
git_committer_email = ARGV[1]
newrev = ARGV[-2]

emails = SVN_TO_EMAILS[svn_account_name]

if emails
  if emails == git_committer_email || emails.include?(git_committer_email)
    exit # OK
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
    open("/home/git/email.log", "a") do |f|
      f.puts "#{ newrev } #{ svn_account_name } #{ git_committer_email }"
    end
  end
end
