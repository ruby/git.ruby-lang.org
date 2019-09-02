#!/usr/bin/env ruby

require "open3"
require "yaml"

ADMIN_USERS = [
  "git",
  "hsbt",
  "naruse",
]

SVN_TO_EMAILS = YAML.safe_load(File.read(File.expand_path('../config/email.yml', __dir__)))
LOG_FILE = "/home/git/email.log"

svn_account_name = ENV["SVN_ACCOUNT_NAME"]
if svn_account_name.nil?
  STDERR.puts "Failed to identify your ssh key."
  STDERR.puts "Maybe ~git/.ssh/authorized_keys is broken."
  STDERR.puts "Please contact on ruby-core@ruby-lang.org."
  exit 1
end

exit 0 if ADMIN_USERS.include?(svn_account_name)

emails = SVN_TO_EMAILS[svn_account_name]

pushable_refnames = [
  'refs/heads/master',
  'refs/heads/trunk',
  'refs/notes/commits',
]

ARGV.each_slice(3) do |oldrev, newrev, refname|
  # `/var/git-svn/ruby` uses `remote.cgit.url=git@git.ruby-lang.org:ruby.git`.
  # ~git/.ssh/id_rsa.pub is registered as `SVN_ACCOUNT_NAME=git` in authorized_keys.
  if !pushable_refnames.include?(refname) && svn_account_name != "git" # git-svn
    STDERR.puts "You pushed '#{newrev}' to '#{refname}', but you can push commits "\
      "to only '#{pushable_refnames.join("', '")}'. (svn_account_name: #{svn_account_name})"
    exit 1
  end

  out, = Open3.capture2("git", "log", "--first-parent", "--pretty=format:%H %ce", oldrev + ".." + newrev)

  out.each_line do |s|
    commit, git_committer_email = s.strip.split(" ", 2)
    if emails
      if emails == git_committer_email || emails.include?(git_committer_email)
        # OK
      else
        STDERR.puts "The git committer email (#{git_committer_email}) does not seem to be #{svn_account_name}'s email (#{emails.join(', ')})."
        STDERR.puts "Please see https://github.com/ruby/ruby-commit-hook/blob/master/config/email.yml"
        STDERR.puts "and send PR, or contact on ruby-core@ruby-lang.org."
        exit 1 # NG
      end
    else
      if Time.now > Time.new(2020, 1, 1)
        STDERR.puts "Your ssh key is unknown."
        STDERR.puts "Please see https://github.com/ruby/ruby-commit-hook/blob/master/config/email.yml"
        STDERR.puts "and send PR, or contact on ruby-core@ruby-lang.org."
        exit 1 # NG
      else
        # Until the last of 2019, we record the association of SVN_ACCOUNT_NAME and GIT_COMMITTER_EMAIL.
        open(LOG_FILE, "a") do |f|
          f.puts "#{ commit } #{ refname } #{ svn_account_name } #{ git_committer_email }"
        end
      end
    end
  end
end
