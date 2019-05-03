#!/usr/bin/env ruby

require "open3"

# This is the correspondence table between SVN_ACCOUNT_NAME and GIT_COMMITTER_EMAIL.
# SVN_ACCOUNT_NAME is set in ~git/.ssh/authorized_keys.
#
# You can add a new email address but DO NOT DELETE already-registered email address.
# This association will be used for committer identification of the ruby repository.

SVN_TO_EMAILS = {
  "duerst" => ["duerst@it.aoyama.ac.jp"],
  "eregon" => ["eregontp@gmail.com", "eregon@ruby-lang.org"],
  "git" => :admin,
  "hsbt" => :admin,
  "k0kubun" => ["takashikkbn@gmail.com"],
  "kazu" => ["zn@mbf.nifty.com"],
  "kou" => ["kou@cozmixng.org", "kou@clear-code.com"],
  "mame" => ["mame@ruby-lang.org"],
  "naruse" => :admin,
  "shyouhei" => ["shyouhei@ruby-lang.org"],
  "suke" => ["masaki.suketa@nifty.ne.jp"],
  "usa" => ["usa@ruby-lang.org"],
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

exit 0 if emails == :admin

ARGV.each_slice(3) do |oldrev, newrev, refname|
  # `/var/git-svn/ruby` uses `remote.cgit.url=git@git.ruby-lang.org:ruby.git`.
  # ~git/.ssh/id_rsa.pub is registered as `SVN_ACCOUNT_NAME=git` in authorized_keys.
  if refname != "refs/heads/trunk" && svn_account_name != "git" # git-svn
    puts "You cannot commit anything to a branch except trunk. (svn_account_name: #{svn_account_name})"
    exit 1
  end

  out, = Open3.capture2("git", "show", "-s", "--pretty=format:%H\n%ce", newrev)

  _hash, git_committer_email = out.split("\n")
  if emails
    if emails == git_committer_email || emails.include?(git_committer_email)
      # OK
    else
      puts "The git committer email (#{git_committer_email}) does not seem to be #{svn_account_name}'s email (#{emails.join(', ')})."
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
        f.puts "#{ oldrev } #{ newrev } #{ svn_account_name } #{ git_committer_email }"
      end
    end
  end
end
