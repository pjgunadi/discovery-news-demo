#!/bin/sh
source .env.setupci

#Login to ICP
echo "1" | bx pr login -a $ICP_URL -u $ICP_USER -p $ICP_PWD --skip-ssl-validation
sleep 2
bx pr cluster-config $CLUSTER_NAME

#Get GitLab URL
GITLAB_URL_NODEPORT=$(kubectl get svc $GITLAB_HELM_RELEASE-gitlab-ce -o=jsonpath='{.spec.ports[?(@.name=="http")].nodePort}')
GITLAB_EXTERNAL_URL=http://$PROXY_IP:$GITLAB_URL_NODEPORT
GITLAB_USER_TOKEN=$(curl -d "login=$GITLAB_USER_ID&password=$GITLAB_USER_PWD" $GITLAB_EXTERNAL_URL/api/v4/session | tr ',' '\n' | sed 's/[{}]//g' | awk -F: -v key='"private_token"' '$1==key {print $2}' | tr -d '"')
GITLAB_PROJECT_ID=$(curl -H "Private-Token: $GITLAB_USER_TOKEN" $GITLAB_EXTERNAL_URL/api/v4/projects?name="$GITLAB_PROJECT_NAME" | tr ',' '\n' | awk -F: -v key='[{"id"' '$1==key {print $2}')
GITLAB_PROJECT_URL=$(curl -H "Private-Token: $GITLAB_USER_TOKEN" $GITLAB_EXTERNAL_URL/api/v4/projects/$GITLAB_PROJECT_ID | tr ',' '\n' | sed 's/[{}]//g' | awk -F: -v key='"http_url_to_repo"' '$1==key {for(i=2; i<=NF; i++) printf "%s", $i (i==NF?ORS:OFS)}' | tr -d '"' | tr ' ' ':')

#Get Jenkins URL
JENKINS_NODEPORT=$(kubectl get svc $JENKINS_HELM_RELEASE -o=jsonpath='{.spec.ports[?(@.name=="http")].nodePort}{"\n"}')
JENKINS_EXTERNAL_URL=http://$PROXY_IP:$JENKINS_NODEPORT

#Credentials
#Create Gitlab Credential
sed -e "s#\(<id>\).*\(</id>\)#\1$GITLAB_CREDENTIAL_ID\2#" \
-e "s#\(<username>\).*\(</username>\)#\1$GITLAB_USER_ID\2#" \
-e "s#\(<password>\).*\(</password>\)#\1$GITLAB_USER_PWD\2#" \
jenkins/gitlab.xml | java -jar jenkins-cli.jar -s $JENKINS_EXTERNAL_URL -auth $JENKINS_TMP_USER:$JENKINS_TMP_PWD \
create-credentials-by-xml system::system::jenkins "(global)"
#Create AWS Access Key
sed -e "s#\(<secret>\).*\(</secret>\)#\1$AWS_ACCESS_KEY\2#" \
jenkins/aws_access_key.xml | java -jar jenkins-cli.jar -s $JENKINS_EXTERNAL_URL -auth $JENKINS_TMP_USER:$JENKINS_TMP_PWD \
create-credentials-by-xml system::system::jenkins "(global)"
#Create AWS Secret Key
sed -e "s#\(<secret>\).*\(</secret>\)#\1$AWS_SECRET_KEY\2#" \
jenkins/aws_secret_key.xml | java -jar jenkins-cli.jar -s $JENKINS_EXTERNAL_URL -auth $JENKINS_TMP_USER:$JENKINS_TMP_PWD \
create-credentials-by-xml system::system::jenkins "(global)"
#Create Bluemix Login
sed -e "s#\(<username>\).*\(</username>\)#\1$BLUEMIX_USER\2#" \
-e "s#\(<password>\).*\(</password>\)#\1$BLUEMIX_PASSWORD\2#" \
jenkins/bluemix_login.xml | java -jar jenkins-cli.jar -s $JENKINS_EXTERNAL_URL -auth $JENKINS_TMP_USER:$JENKINS_TMP_PWD \
create-credentials-by-xml system::system::jenkins "(global)"
#Create CloudFoundry Login
sed -e "s#\(<username>\).*\(</username>\)#\1$CF_USER\2#" \
-e "s#\(<password>\).*\(</password>\)#\1$CF_PASSWORD\2#" \
jenkins/cf_login.xml | java -jar jenkins-cli.jar -s $JENKINS_EXTERNAL_URL -auth $JENKINS_TMP_USER:$JENKINS_TMP_PWD \
create-credentials-by-xml system::system::jenkins "(global)"
#Discovery News Username
sed -e "s#\(<secret>\).*\(</secret>\)#\1$DISCOVERY_USERNAME\2#" \
jenkins/discovery_username.xml | java -jar jenkins-cli.jar -s $JENKINS_EXTERNAL_URL -auth $JENKINS_TMP_USER:$JENKINS_TMP_PWD \
create-credentials-by-xml system::system::jenkins "(global)"
#Discovery News Password
sed -e "s#\(<secret>\).*\(</secret>\)#\1$DISCOVERY_PASSWORD\2#" \
jenkins/discovery_password.xml | java -jar jenkins-cli.jar -s $JENKINS_EXTERNAL_URL -auth $JENKINS_TMP_USER:$JENKINS_TMP_PWD \
create-credentials-by-xml system::system::jenkins "(global)"
#Docker Registry
sed -e "s#\(<username>\).*\(</username>\)#\1$DOCKER_REGISTRY_USER\2#" \
-e "s#\(<password>\).*\(</password>\)#\1$DOCKER_REGISTRY_PASSWORD\2#" \
jenkins/docker_registry.xml | java -jar jenkins-cli.jar -s $JENKINS_EXTERNAL_URL -auth $JENKINS_TMP_USER:$JENKINS_TMP_PWD \
create-credentials-by-xml system::system::jenkins "(global)"
#IBM Cloud Infrastructure Username
sed -e "s#\(<secret>\).*\(</secret>\)#\1$IBM_SL_USERNAME\2#" \
jenkins/ibm_sl_username.xml | java -jar jenkins-cli.jar -s $JENKINS_EXTERNAL_URL -auth $JENKINS_TMP_USER:$JENKINS_TMP_PWD \
create-credentials-by-xml system::system::jenkins "(global)"
#IBM Cloud Infrastructure API Key
sed -e "s#\(<secret>\).*\(</secret>\)#\1$IBM_SL_API_KEY\2#" \
jenkins/ibm_sl_api_key.xml | java -jar jenkins-cli.jar -s $JENKINS_EXTERNAL_URL -auth $JENKINS_TMP_USER:$JENKINS_TMP_PWD \
create-credentials-by-xml system::system::jenkins "(global)"
#Create Private Key
ssh-keygen -f $PRIVATE_KEY_FILE -t rsa -N ''
chmod 600 $PRIVATE_KEY_FILE
#Create Private Key Credential
sed -e "s#\(<fileName>\).*\(</fileName>\)#\1$PRIVATE_KEY_FILE\2#" \
-e "s#\(<secretBytes>\).*\(</secretBytes>\)#\1$(base64 -i $PRIVATE_KEY_FILE)\2#" \
jenkins/private_key.xml | java -jar jenkins-cli.jar -s $JENKINS_EXTERNAL_URL -auth $JENKINS_TMP_USER:$JENKINS_TMP_PWD \
create-credentials-by-xml system::system::jenkins "(global)"
#Create Public Key Credential
sed -e "s#\(<fileName>\).*\(</fileName>\)#\1$PRIVATE_KEY_FILE.pub\2#" \
-e "s#\(<secretBytes>\).*\(</secretBytes>\)#\1$(base64 -i $PRIVATE_KEY_FILE.pub)\2#" \
jenkins/public_key.xml | java -jar jenkins-cli.jar -s $JENKINS_EXTERNAL_URL -auth $JENKINS_TMP_USER:$JENKINS_TMP_PWD \
create-credentials-by-xml system::system::jenkins "(global)"

#Get Plugins Versions
WORKFLOW_JOB_PLUGIN="workflow-job"
WORKFLOW_JOB_PLUGIN_VERSION=$(java -jar jenkins-cli.jar -s $JENKINS_EXTERNAL_URL -auth $JENKINS_TMP_USER:$JENKINS_TMP_PWD list-plugins | awk -v key="$WORKFLOW_JOB_PLUGIN" '$1==key {print $NF}')
GITLAB_PLUGIN="gitlab-plugin"
GITLAB_PLUGIN_VERSION=$(java -jar jenkins-cli.jar -s $JENKINS_EXTERNAL_URL -auth $JENKINS_TMP_USER:$JENKINS_TMP_PWD list-plugins | awk -v key="$GITLAB_PLUGIN" '$1==key {print $NF}')
WORKFLOW_CPS_PLUGIN="workflow-cps"
WORKFLOW_CPS_PLUGIN_VERSION=$(java -jar jenkins-cli.jar -s $JENKINS_EXTERNAL_URL -auth $JENKINS_TMP_USER:$JENKINS_TMP_PWD list-plugins | awk -v key="$WORKFLOW_CPS_PLUGIN" '$1==key {print $NF}')
GIT_PLUGIN="git"
GIT_PLUGIN_VERSION=$(java -jar jenkins-cli.jar -s $JENKINS_EXTERNAL_URL -auth $JENKINS_TMP_USER:$JENKINS_TMP_PWD list-plugins | awk -v key="$GIT_PLUGIN" '$1==key {print $NF}')

#Create Jenkins Job
sed -e "s#\(plugin=\"$WORKFLOW_JOB_PLUGIN@\).*\(\">\)#\1$WORKFLOW_JOB_PLUGIN_VERSION\2#" \
-e "s#\(plugin=\"$GITLAB_PLUGIN@\).*\(\">\)#\1$GITLAB_PLUGIN_VERSION\2#" \
-e "s#\(plugin=\"$WORKFLOW_CPS_PLUGIN@\).*\(\">\)#\1$WORKFLOW_CPS_PLUGIN_VERSION\2#" \
-e "s#\(plugin=\"$GIT_PLUGIN@\).*\(\">\)#\1$GIT_PLUGIN_VERSION\2#" \
-e "s#\(<gitLabConnection>\).*\(</gitLabConnection>\)#\1$GITLAB_CREDENTIAL_ID\2#" \
-e "s#\(<url>\).*\(</url>\)#\1$GITLAB_PROJECT_URL\2#" \
-e "s#\(<credentialsId>\).*\(</credentialsId>\)#\1$GITLAB_CREDENTIAL_ID\2#" \
discovery-news.xml | java -jar jenkins-cli.jar -s $JENKINS_EXTERNAL_URL -auth $JENKINS_TMP_USER:$JENKINS_TMP_PWD \
create-job $JENKINS_PROJECT_NAME