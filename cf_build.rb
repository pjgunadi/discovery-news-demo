require 'dotenv'
Dotenv.load ".env.cf"
require_relative "build_libs/helpers"

namespace "cf" do
  reset_task_index

  desc "update wildcard cf login"
  task "#{next_task_index}_update_etc_hosts" do
    %w(login api).each do |host|
      etc_hosts_entry = sprintf("%s %s.%s", ENV["HA_PROXY_IP"], host, ENV["CF_DOMAIN"])
      sh %Q(echo "#{etc_hosts_entry}" >> /etc/hosts)
    end
  end

  desc "setup app"
  task "#{next_task_index}_setup_app" do
    # https://api.mgmt.cf.sgcc.demo.lan
    api_url = "https://api.#{ENV["CF_DOMAIN"]}"
    puts %Q(cf login -a #{api_url} -u #{ENV["CF_USER"]} -p #{ENV["CF_PASSWORD"]} -o "#{ENV["CF_ORG"]}" -s "#{ENV["CF_SPACE"]}")
    sh %Q(cf login -a #{api_url} -u #{ENV["CF_USER"]} -p #{ENV["CF_PASSWORD"]} -o "#{ENV["CF_ORG"]}" -s "#{ENV["CF_SPACE"]}" --skip-ssl-validation)
  end

end

