execute 'systemctl daemon-reload' do
  action :nothing
end

remote_file '/etc/systemd/system/git-sync-check.service' do
  mode  '644'
  owner 'root'
  notifies :run, 'execute[systemctl daemon-reload]'
end

remote_file '/etc/systemd/system/git-sync-check.timer' do
  mode  '644'
  owner 'root'
  notifies :run, 'execute[systemctl daemon-reload]'
end
