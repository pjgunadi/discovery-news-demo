require 'dotenv'
Dotenv.load ".env.build"
require_relative "build_libs/helpers"

image_name = ENV["IMAGE_NAME"]
tag=ENV["BUILD_NUMBER"]||"B1"

namespace "docker" do
  reset_task_index

  desc "build docker image"
  task "#{next_task_index}_build_image" do
     #Debug
    sh %Q(echo Image Name: #{image_name}:#{tag})
    #Delete previous images
    t = tag.to_i - 2
    if (t > 0)
      (1..t).each do |i|
        sh %Q([ "$(docker images #{image_name}:#{i} -q)" != "" ] && docker rmi #{image_name}:#{i} || echo "No existing image found")
      end
    end
    sh %Q([ "$(docker images #{image_name}:#{tag} -q)" != "" ] && docker rmi #{image_name}:#{tag} || echo "No existing image found")
    sh %Q(docker build -t #{image_name}:#{tag} .)
  end

  desc "push to ICp registry"
  task "#{next_task_index}_push_to_ICp_registry" do
    DockerTools.add_etc_hosts
    DockerTools.push_to_registry image_name, tag
  end
end

namespace "k8s" do
  reset_task_index

  desc "deploy into k8s"
  task "#{next_task_index}_deploy_to_k8s" do
    yaml_template_file = "#{image_name}.k8.template.yaml"
    yaml_file = "#{image_name}.yaml"

    private_registry = sprintf("%s:%s", ENV["PRIVATE_DOCKER_REGISTRY_NAME"], ENV["PRIVATE_DOCKER_REGISTRY_PORT"])
    namespace = ENV["PRIVATE_DOCKER_REGISTRY_NAMESPACE"]
    full_new_image_name = "#{private_registry}/#{namespace}/#{image_name}:#{tag}"
    data = {
      new_image: full_new_image_name
    }

    KubeTools.create_new_yaml yaml_template_file, yaml_file, data

    deployment = image_name
    KubeTools.deploy_to_k8s ENV["K8S_NAMESPACE"], deployment, yaml_file, image_name, full_new_image_name
    sh %Q(echo URL: http://$PROXY_IP:$(kubectl -n dev get svc discovery-news -o=jsonpath={.spec.ports[*].nodePort}))
  end
end    
