require 'dotenv'
Dotenv.load ".env.bluemix"
require_relative "build_libs/helpers"

namespace "bx" do
  reset_task_index

  desc "setup app"
  task "#{next_task_index}_setup_app" do
    cmd =  %Q(cf login -a #{ENV["BLUEMIX_ENDPOINT"]} -u #{ENV["BLUEMIX_USER"]} -p #{ENV["BLUEMIX_PASSWORD"]} -o "#{ENV["BLUEMIX_ORG"]}" -s "#{ENV["BLUEMIX_SPACE"]}")
    sh cmd
  end

end

