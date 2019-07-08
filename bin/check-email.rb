#!/usr/bin/env ruby

require "open3"

# This is the correspondence table between SVN_ACCOUNT_NAME and GIT_COMMITTER_EMAIL.
# SVN_ACCOUNT_NAME is set in ~git/.ssh/authorized_keys.
#
# You can add a new email address but DO NOT DELETE already-registered email address.
# This association will be used for committer identification of the ruby repository.

SVN_TO_EMAILS = {
  "aycabta" => ["aycabta@gmail.com"],
  "duerst" => ["duerst@it.aoyama.ac.jp"],
  "eregon" => ["eregontp@gmail.com", "eregon@ruby-lang.org"],
  "git" => :admin,
  "hsbt" => :admin,
  "jeremy" => ["code@jeremyevans.net"],
  "k0kubun" => ["takashikkbn@gmail.com"],
  "kazu" => ["zn@mbf.nifty.com"],
  "ko1" => ["ko1@atdot.net"],
  "kou" => ["kou@cozmixng.org", "kou@clear-code.com"],
  "ktsj" => ["kazuki@callcc.net"],
  "mame" => ["mame@ruby-lang.org"],
  "nagachika" => ["nagachika@ruby-lang.org"],
  "naruse" => :admin,
  "nobu" => ["nobu@ruby-lang.org"],
  "samuel" => ["samuel.williams@oriontransfer.co.nz"],
  "seki" => ["m_seki@mva.biglobe.ne.jp"],
  "sorah" => ["her@sorah.jp", "sorah@cookpad.com"],
  "shugo" => ["shugo@ruby-lang.org"],
  "shyouhei" => ["shyouhei@ruby-lang.org"],
  "stomar" => ["sto.mar@web.de"],
  "suke" => ["masaki.suketa@nifty.ne.jp"],
  "tenderlove" => ["aaron.patterson@gmail.com", "tenderlove@ruby-lang.org"],
  "usa" => ["usa@ruby-lang.org"],
  "yugui" => ["yugui@yugui.jp"],
}

LOG_FILE = "/home/git/email.log"

svn_account_name = ENV["SVN_ACCOUNT_NAME"]
if svn_account_name.nil?
  STDERR.puts "Failed to identify your ssh key."
  STDERR.puts "Maybe ~git/.ssh/authorized_keys is broken."
  STDERR.puts "Please contact on ruby-core@ruby-lang.org."
  exit 1
end

emails = SVN_TO_EMAILS[svn_account_name]

exit 0 if emails == :admin

pushable_refnames = [
  'refs/heads/master',
  'refs/heads/trunk',
]

ARGV.each_slice(3) do |oldrev, newrev, refname|
  # `/var/git-svn/ruby` uses `remote.cgit.url=git@git.ruby-lang.org:ruby.git`.
  # ~git/.ssh/id_rsa.pub is registered as `SVN_ACCOUNT_NAME=git` in authorized_keys.
  if !pushable_refnames.include?(refname) && svn_account_name != "git" # git-svn
    STDERR.puts "You cannot commit anything to a branch except #{pushable_refnames.map(&File.method(:basename)).join(', ')}. (svn_account_name: #{svn_account_name})"
    exit 1
  end

  out, = Open3.capture2("git", "show", "-s", "--pretty=format:%H\n%ce", newrev)

  _hash, git_committer_email = out.split("\n")
  if emails
    if emails == git_committer_email || emails.include?(git_committer_email)
      # OK
    else
      STDERR.puts "The git committer email (#{git_committer_email}) does not seem to be #{svn_account_name}'s email (#{emails.join(', ')})."
      STDERR.puts "Please see https://github.com/ruby/ruby-commit-hook/blob/master/bin/check-email.rb"
      STDERR.puts "and send PR, or contact on ruby-core@ruby-lang.org."
      exit 1 # NG
    end
  else
    if Time.now > Time.new(2020, 1, 1)
      STDERR.puts "Your ssh key is unknown."
      STDERR.puts "Please see https://github.com/ruby/ruby-commit-hook/blob/master/bin/check-email.rb"
      STDERR.puts "and send PR, or contact on ruby-core@ruby-lang.org."
      exit 1 # NG
    else
      # Until the last of 2019, we record the association of SVN_ACCOUNT_NAME and GIT_COMMITTER_EMAIL.
      open(LOG_FILE, "a") do |f|
        f.puts "#{ oldrev } #{ newrev } #{ refname } #{ svn_account_name } #{ git_committer_email }"
      end
    end
  end
end
