include_recipe 'bullseye-backports'

package 'cgit'
package 'certbot'
package 'git/bullseye-backports'
package 'ruby'
package 'postfix'
package 'gpg'
package 'rsync'

include_recipe 'apache2'
include_recipe 'cgit'
include_recipe 'git-user'
include_recipe 'git-sync-check'

remote_file '/etc/sudoers'
