# git.ruby-lang.org ![test](https://github.com/ruby/git.ruby-lang.org/workflows/test/badge.svg)

## Features

On each commit of Ruby's Git repository, following git hooks are triggered:

### pre-receive

* Verify committer email from `SVN_ACCOUNT_NAME` associated to SSH key used for `git push`
* Reject merge commits (ask @mame about why)

### post-receive

* Send notification to ruby-cvs@ruby-lang.org
* Commit automatic styling:
  * remove trailing spaces
  * append newline at EOF
  * expand tabs
* Update version.h if date is changed
* Request Redmine to fetch changesets
* Mirror cgit to GitHub
* Notify committer's Slack

## The directory structure of `git.ruby-lang.org`

* `/data/git/ruby.git`: Bare Git repository of ruby
  * `hooks/post-receive`: Run `/home/git/git.ruby-lang.org/hooks/post-receive.sh`
* `/home/git/git.ruby-lang.org`: Cloned Git repository of git.ruby-lang.org

### Notes

* There's a symlink `/var/git` -> `/data/git`.
* User `git`'s `$HOME` is NOT `/home/git` but `/var/git`.

## How to deploy `ruby/git.ruby-lang.org`

### Authentication

* We use only `admin` user for `git.ruby-lang.org`'s SSH access.
  * You should contact @hsbt, @mame or @k0kubun for accessing `git.ruby-lang.org`.

### bin, cgi-bin, hooks
* `git push` to `ruby/git.ruby-lang.org`'s master branch automatically updates them.
  * `ruby/git.ruby-lang.org` push webhook triggers `cgi-bin/webhook.cgi`
  * It runs `sudo -u git bin/update-git-ruby-lang-org.sh`

### recipes

```bash
# dry-run
bin/hocho apply -n git.ruby-lang.org

# apply
bin/hocho apply git.ruby-lang.org
```

### TODO for recipes for git.ruby-lang.org

* How to store `ssh_host_key*` and `sshd_config` safely?
* How to write a recipe to mount data volume for bare git repository?
* How to write a recipe for mackerel with the host key of git.ruby-lang.org?

## How to set up default gem sync

1. Add your gem repository name to `DEFAULT_GEM_REPOS` in [cgi-bin/webhook.cgi](./cgi-bin/webhook.cgi), and push it to master.
2. Go to `https://github.com/ruby/{repo_name}/settings/hooks`, and add a webhook
     * Payload URL: Set the content of `~git/config/git-ruby-lang-org-url` in git.ruby-lang.org
     * Content type: application/json
     * Secret: Set the content of `~git/config/git-ruby-lang-org-secret` in git.ruby-lang.org
     * Which events: Just the push event.

## License

[Ruby License](./license.txt)
