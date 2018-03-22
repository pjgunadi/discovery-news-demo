require 'sshkit_addon'
require 'dotenv'
Dotenv.load

user = "ubuntu"
password = "password"
master = SSHKit::Host.new :hostname => "192.168.64.222", :user => user, :password => password
master_ip = "192.168.64.222"

@task_index=0
def next_task_index
  @task_index += 1
  sprintf("%02d", @task_index)
end

namespace "util" do
  desc "run command"
  task :run_command, [:cmd] do |t, args|
    cmd = args.cmd
    on master do |host|
       execute cmd
    end
  end
end

target_dir = "discovery_news"

desc "upload"
task "#{next_task_index}_upload" do
  on master do |host|
    execute %Q(mkdir -p #{target_dir})
    upload! ".", target_dir, recursive: true
  end
end

desc "build"
task "#{next_task_index}_build" do
  on master do |host|
    cmds = ShellCommandConstructor.construct_command %Q{
      cd /discovery_news/app
      npm install

      npm run build
    }    
    content = <<~EOF
      FROM node:8.4
      
      WORKDIR /discovery_news
      COPY . /discovery_news
      
      RUN #{cmds}

      CMD ["bash", "-c", "cd app; node server"]
    EOF

    put content, target_dir + "/Dockerfile"
    File.open "Dockerfile", "w" do |fh|
      fh.puts content
    end
    
    # cmds = ShellCommandConstructor.construct_command %Q{
    #    cd #{target_dir}
    #    sudo docker build -t discoverynews:0.1.0 .
    # }

    # execute cmds
  end
end
