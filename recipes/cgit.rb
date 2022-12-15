remote_file "/etc/cgitrc" do
  mode  "644"
  owner "root"
end

remote_file "/usr/share/cgit/ruby.png" do
  mode  "644"
  owner "root"
end

remote_file "/var/git/.ssh/authorized_keys" do
  mode  "600"
  owner "git"
end
