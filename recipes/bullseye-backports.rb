execute 'apt update' do
  action :nothing
end

# Use newer git: 2.34.x+ instead of 2.30.x
remote_file '/etc/apt/sources.list.d/bullseye-backports.list' do
  notifies :run, 'execute[apt update]'
end
