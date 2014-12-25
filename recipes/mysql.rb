mysql = node['ghost']['mysql']
mysql_service 'ghost' do
  port '3306'
  version '5.6'
  initial_root_password mysql[:password]
  provider Chef::Provider::MysqlService::Upstart
  action [:create, :start]
end

mysql_client 'ghost' do
  version '5.6'
  action :create
end

mysql_config 'ghost' do
    notifies :restart, 'mysql_service[ghost]'
    action :create
    version '5.6'
    source 'ghost-mysql.cnf.erb'
    variables mysql
end

# create table
mysql_chef_gem 'default' do
  action :install
end


this_mysql_connection = {
  :host => node['ghost']['app']['database']['host'],
  :username => 'root',
  :password => mysql[:password]
}

mysql_database "ghost" do
  connection this_mysql_connection
  action :create
end
