service 'datadog-agent' do
  action :nothing
end

execute 'systemctl daemon-reload (datadog)' do
  command 'systemctl daemon-reload'
  action :nothing
end

# Enable log collection via an environment override so the secret-bearing
# datadog.yaml (API key, site) is left untouched.
directory '/etc/systemd/system/datadog-agent.service.d' do
  mode  '755'
  owner 'root'
end

remote_file '/etc/systemd/system/datadog-agent.service.d/override.conf' do
  mode  '644'
  owner 'root'
  notifies :run, 'execute[systemctl daemon-reload (datadog)]'
  notifies :restart, 'service[datadog-agent]'
end

# Tail Apache2 access/error logs.
directory '/etc/datadog-agent/conf.d/apache.d' do
  mode  '755'
  owner 'dd-agent'
  group 'dd-agent'
end

remote_file '/etc/datadog-agent/conf.d/apache.d/conf.yaml' do
  mode  '644'
  owner 'dd-agent'
  group 'dd-agent'
  notifies :restart, 'service[datadog-agent]'
end

# dd-agent needs the adm group to read /var/log/apache2 (root:adm, mode 640).
group 'adm' do
  members ['dd-agent']
  append true
  action :modify
  notifies :restart, 'service[datadog-agent]'
end
