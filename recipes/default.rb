include_recipe 'apache2'
include_recipe 'git-sync-check'

remote_file '/etc/sudoers'
