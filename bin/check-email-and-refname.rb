#!/usr/bin/env ruby
# This script is hooked by pre-receive hook of ruby.git to:
#   * Make sure the pusher uses his/her "committer email", based on `config/email.yml`.
#   * Prohibit creating topic branches on ruby.git.

require "open3"
require "yaml"

ADMIN_USERS = [
  "git",
  "hsbt",
  "k0kubun",
  "naruse",
]
STABLE_BRANCH_MAINTAINERS = [
  "k0kubun",
  "nagachika",
]
PUSHABLE_REFNAMES = [
  "refs/heads/master",
  "refs/notes/commits",
  "refs/notes/log-fix",
]

def is_pushable_stable_branch?(refname)
  %r{\Arefs/heads/ruby_(\d+)_(\d+)\Z} =~ refname and (($1 == "2" and $2.to_i >= 7) or ($1.to_i >= 3))
end

def is_pushable_stable_tag?(refname)
  %r{\Arefs/tags/v(\d+)_(\d+)_(\d+)\Z} =~ refname and (($1 == "2" and $2.to_i >= 7) or ($1.to_i >= 3))
end

def is_pushable_by_branch_maintainer?(refname)
  is_pushable_stable_branch?(refname) || is_pushable_stable_tag?(refname)
end

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

ARGV.each_slice(3) do |oldrev, newrev, refname|
  # `/var/git-svn/ruby` uses `remote.cgit.url=git@git.ruby-lang.org:ruby.git`.
  # ~git/.ssh/id_rsa.pub is registered as `SVN_ACCOUNT_NAME=git` in authorized_keys.
  unless PUSHABLE_REFNAMES.include?(refname) || svn_account_name == "git" || # git-svn
         (is_pushable_by_branch_maintainer?(refname) && STABLE_BRANCH_MAINTAINERS.include?(svn_account_name)) # stable maintainer
    STDERR.puts "You pushed '#{newrev}' to '#{refname}', but you can push commits "\
      "to only '#{PUSHABLE_REFNAMES.join("', '")}'. (svn_account_name: #{svn_account_name})"
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
        STDERR.puts "Please see https://github.com/ruby/git.ruby-lang.org/blob/master/config/email.yml"
        STDERR.puts "and send PR, or contact on ruby-core@ruby-lang.org."
        exit 1 # NG
      end
    else
      if Time.now > Time.new(2020, 1, 1)
        STDERR.puts "Your ssh key is unknown."
        STDERR.puts "Please see https://github.com/ruby/git.ruby-lang.org/blob/master/config/email.yml"
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
