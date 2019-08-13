#!/usr/bin/env ruby
# This is executed by `/lib/systemd/system/git-sync-check.service` as User=git
# which is triggered every 10 minutes by `/lib/systemd/system/git-sync-check.timer`.

module Git
  # cgit bare repository
  GIT_DIR = '/var/git/ruby.git'

  class << self
    def show_ref
      git('show-ref')
    end

    def ls_remote(remote)
      git('ls-remote', remote)
    end

    private

    def git(*cmd)
      out = IO.popen({ 'GIT_DIR' => GIT_DIR }, ['git', *cmd], &:read)
      unless $?.success?
        raise "Failed to execute: git #{cmd.join(' ')}"
      end
      out
    end
  end
end

# Quickly finish collecting facts to avoid a race condition as much as possible.
# TODO: Retry this operation several times if the race happens often.
ls_remote = Git.ls_remote('github')
show_ref  = Git.show_ref

# Start digesting the data after the collection.
remote_refs = Hash[ls_remote.lines.map { |l| rev, ref = l.chomp.split("\t"); [ref, rev] }]
local_refs  = Hash[show_ref.lines.map  { |l| rev, ref = l.chomp.split(' ');  [ref, rev] }]

# Remove refs which are not to be checked here.
remote_refs.delete('HEAD') # show-ref does not show it
remote_refs.keys.each { |ref| remote_refs.delete(ref) if ref.match(%r[\Arefs/pull/\d+/\w+\z]) } # pull requests

# Check consistency
errors = []
(remote_refs.keys | local_refs.keys).each do |ref|
  remote_rev = remote_refs[ref]
  local_rev  = local_refs[ref]

  if remote_rev != local_rev
    errors << [remote_rev, local_rev]
  end
end

if errors.empty?
  puts 'SUCCUESS: Everything is consistent.'
else
  puts 'FAILURE: Following inconsistencies are found.'
  errors.each do |remote_rev, local_rev|
    puts "remote:#{remote_rev.inspect} local:#{local_rev.inspect}"
  end
end
