require_relative 'spec_helper'

describe 'Ghost' do

  describe command('which node') do
    its(:stdout) { should match /node/ }
  end

  describe command('which nginx') do
    its(:stdout) { should match /nginx/ }
  end

  describe service('ghost') do
    it { should be_running }
  end

  describe user('ghost') do
    it { should exist }
  end

  describe group('ghost') do
    it { should exist }
  end

  describe file('/srv/ghost') do
    it { should be_directory }
  end

  describe file('/srv/ghost/content') do
    it { should be_directory }
  end

  describe file('/srv/ghost/releases') do
    it { should be_directory }
  end

  describe file('/etc/nginx/sites-available/default') do
    it { should be_file }
  end

  describe port(2368) do
    it { should be_listening }
  end

  describe port(80) do
    it { should be_listening }
  end

end
