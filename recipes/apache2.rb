execute 'systemctl daemon-reload' do
  action :nothing
end

directory '/etc/systemd/system/apache2.service.d' do
  mode  '755'
  owner 'root'
end

remote_file '/etc/systemd/system/apache2.service.d/override.conf' do
  mode  '644'
  owner 'root'
  notifies :run, 'execute[systemctl daemon-reload]'
end

service 'apache2' do
  action :nothing
end

remote_file '/etc/apache2/sites-available/git.ruby-lang.org.conf' do
  mode  '644'
  owner 'root'
  notifies :reload, 'service[apache2]'
end

link '/etc/apache2/sites-enabled/git.ruby-lang.org.conf' do
  to '../sites-available/git.ruby-lang.org.conf'
end
