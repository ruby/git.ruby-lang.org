#!/usr/bin/env ruby
# Add GitHub pull request reference to git notes.

require 'net/http'
require 'uri'
require 'tmpdir'
require 'json'

class GitHub
  ENDPOINT = URI.parse('https://api.github.com')

  def initialize(access_token)
    @access_token = access_token
  end

  # https://developer.github.com/changes/2019-04-11-pulls-branches-for-commit/
  def pulls(owner:, repo:, commit_sha:)
    resp = get("/repos/#{owner}/#{repo}/commits/#{commit_sha}/pulls", accept: 'application/vnd.github.groot-preview+json')
    JSON.parse(resp.body)
  end

  private

  def get(path, accept: 'application/vnd.github.v3+json')
    Net::HTTP.start(ENDPOINT.host, ENDPOINT.port, use_ssl: ENDPOINT.scheme == 'https') do |http|
      headers = { 'Accept': accept, 'Authorization': "bearer #{@access_token}" }
      http.get(path, headers).tap(&:value)
    end
  end
end

module Git
  class << self
    def abbrev_ref(refname, repo_path:)
      git('rev-parse', '--symbolic', '--abbrev-ref', refname, repo_path: repo_path).strip
    end

    def rev_list(arg, first_parent: false, repo_path: nil)
      git('rev-list', *[('--first-parent' if first_parent)].compact, arg, repo_path: repo_path).lines.map(&:chomp)
    end

    def commit_message(sha)
      git('log', '-1', '--pretty=format:%B', sha)
    end

    def notes_message(sha)
      git('log', '-1', '--pretty=format:%N', sha)
    end

    private

    def git(*cmd, repo_path: nil)
      env = {}
      if repo_path
        env['GIT_DIR'] = repo_path
      end
      out = IO.popen(env, ['git', *cmd], &:read)
      unless $?.success?
        abort "Failed to execute: git #{cmd.join(' ')}\n#{out}"
      end
      out
    end
  end
end

github = GitHub.new(File.read(File.expand_path('~git/config/github-access-token')).chomp)

repo_path, *rest = ARGV
rest.each_slice(3).map do |oldrev, newrev, refname|
  branch = Git.abbrev_ref(refname, repo_path: repo_path)
  next if branch != 'master' # we use pull requests only for master branches

  Dir.mktmpdir do |workdir|
    depth = Git.rev_list("#{oldrev}..#{newrev}", repo_path: repo_path).size + 1
    system('git', 'clone', "--depth=#{depth}", "--branch=#{branch}", "file:///#{repo_path}", workdir)
    Dir.chdir(workdir)

    updated = false
    Git.rev_list("#{oldrev}..#{newrev}", first_parent: true).each do |sha|
      github.pulls(owner: 'ruby', repo: 'ruby', commit_sha: sha).each do |pull|
        number = pull.fetch('number')
        url = pull.fetch('url')

        message = Git.commit_message(sha)
        notes = Git.notes_message(sha)
        if !message.include?(url) && !message.include?("(##{number})") && !notes.include?(url)
          system('git', 'notes', 'append', '-m', "Merged: #{url}", sha)
          updated = true
        end
      end
    end

    if updated
      system('git', 'push', 'origin', 'refs/notes/commits')
    end
  end
end
