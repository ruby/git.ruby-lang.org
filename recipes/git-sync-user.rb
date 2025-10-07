user "git-sync" do
  shell "/bin/bash"
  home "/home/git-sync"
end

directory "/home/git-sync" do
  owner "git-sync"
  group "git-sync"
  mode "0755"
end

directory "/home/git-sync/.ssh" do
  owner "git-sync"
  group "git-sync"
  mode "0700"
end

remote_file "/home/git-sync/.ssh/authorized_keys" do
  owner "git-sync"
  group "git-sync"
  mode  "600"
end
