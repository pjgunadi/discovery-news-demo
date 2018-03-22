//A Jenkinsfile for start
podTemplate(label: 'jenkins-tf',
  containers:[
    containerTemplate(name: 'compiler', image:'node:8.4',ttyEnabled: true, command: 'cat', envVars:[
        containerEnvVar(key: 'BUILD_NUMBER', value: env.BUILD_NUMBER),
        containerEnvVar(key: 'BUILD_ID', value: env.BUILD_ID),
        containerEnvVar(key: 'BUILD_URL', value: env.BUILD_URL),
        containerEnvVar(key: 'BUILD_TAG', value: env.BUILD_TAG),
        containerEnvVar(key: 'JOB_NAME', value: env.JOB_NAME),
        containerEnvVar(key: 'CI', value: 'true')
      ],
    ),
    containerTemplate(name: 'citools', image:'zhiminwen/citools',ttyEnabled: true, command: 'cat', envVars:[
        // these env is only available in container template? podEnvVar deosn't work?!
        containerEnvVar(key: 'BUILD_NUMBER', value: env.BUILD_NUMBER),
        containerEnvVar(key: 'BUILD_ID', value: env.BUILD_ID),
        containerEnvVar(key: 'BUILD_URL', value: env.BUILD_URL),
        containerEnvVar(key: 'BUILD_TAG', value: env.BUILD_TAG),
        containerEnvVar(key: 'JOB_NAME', value: env.JOB_NAME),
        containerEnvVar(key: 'CI', value: 'true')
      ],
    ),    
    containerTemplate(name: 'terraform', image:'hashicorp/terraform:light',ttyEnabled: true, command: 'cat', envVars:[
        containerEnvVar(key: 'BUILD_NUMBER', value: env.BUILD_NUMBER),
        containerEnvVar(key: 'BUILD_ID', value: env.BUILD_ID),
        containerEnvVar(key: 'BUILD_URL', value: env.BUILD_URL),
        containerEnvVar(key: 'BUILD_TAG', value: env.BUILD_TAG),
        containerEnvVar(key: 'JOB_NAME', value: env.JOB_NAME),
        containerEnvVar(key: 'CI', value: 'true')
      ],
    )
  ],
  volumes: [
    //for docker to work
    hostPathVolume(hostPath: '/var/run/docker.sock', mountPath: '/var/run/docker.sock')
  ]
){
  node('jenkins-tf') {
    stage('clone git repo'){
      checkout scm
      
      container('compiler'){
        stage('Compile'){
          withCredentials([string(credentialsId: 'discovery_username', variable: 'discovery_username'),
            string(credentialsId: 'discovery_password', variable: 'discovery_password'),
            usernamePassword(credentialsId: 'docker_registry', usernameVariable: 'registry_user', passwordVariable: 'registry_password'),
            usernamePassword(credentialsId: 'cf_login', usernameVariable: 'cf_user', passwordVariable: 'cf_password'),
            usernamePassword(credentialsId: 'bluemix_login', usernameVariable: 'bx_user', passwordVariable: 'bx_password')
            ]) {
              echo "compile"
              sh """
              echo "PRIVATE_DOCKER_REGISTRY_USER=${registry_user}" | tee -a .env.build
              echo "PRIVATE_DOCKER_REGISTRY_USER_PASSWORD=${registry_password}" | tee -a .env.build
              echo "CF_USER=${cf_user}" | tee -a .env.cf
              echo "CF_PASSWORD=${cf_password}" | tee -a .env.cf
              echo "BLUEMIX_USER=${bx_user}" | tee -a .env.bluemix
              echo "BLUEMIX_PASSWORD=${bx_password}" | tee -a .env.bluemix
              echo "BLUEMIX_ORG=${bx_user}" | tee -a .env.bluemix
              cd app
              echo "DISCOVERY_USERNAME=${discovery_username}" | tee .env
              echo "DISCOVERY_PASSWORD=${discovery_password}" | tee -a .env
              rm -rf build/* && npm install
              """
          }
        }
        stage('Test and Build') {
          if (test_app == "true") {
            echo "Perform Testing..."
            sh """
            cd app
            npm test
            """
          } else {
            echo "Skip Testing"
            sh """
            cd app
            npm run build
            """
          }
        }
      }
      parallel(
        "Deploy Kubernetes": {
          container('citools'){
            if (build_k8s == "true") {
              stage('Deploy into k8s'){
                sh """
                echo build docker image
                #source .env.build
                #export NEWTAG=${BUILD_NUMBER}
                rake -f build.rb docker:01_build_image docker:02_push_to_ICp_registry
                echo rollout to k8s
                rake -f build.rb k8s:01_deploy_to_k8s
                #echo "URL: http://\$PROXY_IP:"\$(kubectl -n dev get svc discovery-news -o=jsonpath={.spec.ports[*].nodePort})
                """
              }
            }
          }
        },
        "Deploy CloudFoundry": {
          container('citools'){
            if (build_cf == "true") {
              stage('Deploy into cf'){
                echo "rollout to cf"
                sh """
                rake -f cf_build.rb cf:01_update_etc_hosts cf:02_setup_app
                cd app
                cf push -b https://github.com/cloudfoundry/nodejs-buildpack
                """
              }
            }
          }
        },
        "Deploy Bluemix": {
          container('citools'){
            if (build_bx == "true") {
              stage('Deploy into bluemix'){
                echo "rollout to bluemix"
                sh """
                rake -f bluemix_build.rb bx:01_setup_app
                cd app
                cf push
                """
              }
            }
          }
        },
        "Deploy AWS": {
          container('terraform'){
            if(build_aws == "true") {
              stage('Apply AWS') {
                withCredentials([string(credentialsId: 'aws_access_key', variable: 'access_key'),
                string(credentialsId: 'aws_secret_key', variable: 'secret_key'),
                string(credentialsId: 'discovery_username', variable: 'discovery_username'),
                string(credentialsId: 'discovery_password', variable: 'discovery_password'),
                file(credentialsId: 'public_key', variable: 'public_key'),
                file(credentialsId: 'private_key', variable: 'private_key')]) {
                  sh """
                  cd aws
                  terraform init -backend=true -backend-config="access_key=${access_key}" -backend-config="secret_key=${secret_key}"
                  terraform taint null_resource.discovery_news || echo "new deployment"
                  terraform plan -var "access_key=${access_key}" -var "secret_key=${secret_key}" \
                    -var "discovery_username=${discovery_username}" -var "discovery_password=${discovery_password}" \
                    -var "public_key=${public_key}" -var "private_key=${private_key}"
                  terraform apply -var "access_key=${access_key}" -var "secret_key=${secret_key}" \
                    -var "discovery_username=${discovery_username}" -var "discovery_password=${discovery_password}" \
                    -var "public_key=${public_key}" -var "private_key=${private_key}" \
                    -auto-approve=true
                  """          
                }
              }
            }
          }
        },
        "Deploy SoftLayer": {
          container('terraform'){
            if (build_sl == "true") {
              stage('Apply SoftLayer') {
                withCredentials([string(credentialsId: 'aws_access_key', variable: 'backend_access_key'),
                string(credentialsId: 'aws_secret_key', variable: 'backend_secret_key'),
                string(credentialsId: 'ibm_sl_username', variable: 'ibm_sl_username'),
                string(credentialsId: 'ibm_sl_api_key', variable: 'ibm_sl_api_key'),
                string(credentialsId: 'discovery_username', variable: 'discovery_username'),
                string(credentialsId: 'discovery_password', variable: 'discovery_password'),
                file(credentialsId: 'public_key', variable: 'public_key'),
                file(credentialsId: 'private_key', variable: 'private_key')]) {
                  sh """
                  cd sl
                  terraform init -backend=true -backend-config="access_key=${backend_access_key}" -backend-config="secret_key=${backend_secret_key}"
                  terraform taint null_resource.discovery_news || echo "new deployment"
                  terraform plan -var "ibm_sl_username=${ibm_sl_username}" -var "ibm_sl_api_key=${ibm_sl_api_key}" \
                    -var "discovery_username=${discovery_username}" -var "discovery_password=${discovery_password}" \
                    -var "public_key=${public_key}" -var "private_key=${private_key}"
                  terraform apply -var "ibm_sl_username=${ibm_sl_username}" -var "ibm_sl_api_key=${ibm_sl_api_key}" \
                    -var "discovery_username=${discovery_username}" -var "discovery_password=${discovery_password}" \
                    -var "public_key=${public_key}" -var "private_key=${private_key}" \
                    -auto-approve=true
                  """          
                }
              }
            }
          }
        }
      )
    }
  }
}
