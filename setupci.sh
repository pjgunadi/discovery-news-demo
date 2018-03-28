#!/bin/sh
source .env.setupci

#Login to ICP
echo "1" | bx pr login -a $ICP_URL -u $ICP_USER -p $ICP_PWD --skip-ssl-validation
sleep 2
bx pr cluster-config $CLUSTER_NAME

#Setup Namespace
./setup_namespace.sh "$GITLAB_NAMESPACE" "$K8_SECRET_NAME" "$REGISTRY_SERVER" "$REGISTRY_PORT" "$DOCKER_REGISTRY_USER" "$DOCKER_REGISTRY_PASSWORD"
./setup_namespace.sh "$JENKINS_NAMESPACE" "$K8_SECRET_NAME" "$REGISTRY_SERVER" "$REGISTRY_PORT" "$DOCKER_REGISTRY_USER" "$DOCKER_REGISTRY_PASSWORD"
./setup_namespace.sh "$TARGET_NAMESPACE" "$K8_SECRET_NAME" "$REGISTRY_SERVER" "$REGISTRY_PORT" "$DOCKER_REGISTRY_USER" "$DOCKER_REGISTRY_PASSWORD"

#Get GitLab and Jenkins Port
echo "Get Gitlab Deployment details"
GITLAB_CLUSTER_URL=$(kubectl get deploy $GITLAB_HELM_RELEASE-gitlab-ce -o=jsonpath='{.spec.template.spec.containers[*].env[?(@.name=="EXTERNAL_URL")].value}')
GITLAB_URL_NODEPORT=$(kubectl get svc $GITLAB_HELM_RELEASE-gitlab-ce -o=jsonpath='{.spec.ports[?(@.name=="http")].nodePort}')
GITLAB_EXTERNAL_URL=http://$PROXY_IP:$GITLAB_URL_NODEPORT

echo "Get Jenkins Deployment details"
JENKINS_NODEPORT=$(kubectl get svc $JENKINS_HELM_RELEASE -o=jsonpath='{.spec.ports[?(@.name=="http")].nodePort}{"\n"}')
JENKINS_PORT=$(kubectl get svc $JENKINS_HELM_RELEASE -o=jsonpath='{.spec.ports[?(@.name=="http")].port}{"\n"}')
JENKINS_CLUSTER_URL=http://$JENKINS_HELM_RELEASE:$JENKINS_PORT
JENKINS_EXTERNAL_URL=http://$PROXY_IP:$JENKINS_NODEPORT
JENKINS_ADMIN_PWD=$(kubectl get secrets $JENKINS_HELM_RELEASE -o jsonpath='{.data.jenkins-admin-password}' | base64 -D)

#Configure GitLab
GITLAB_ROOT_TOKEN=$(curl -d "login=root&password=$GITLAB_ROOT_PASSWORD" $GITLAB_EXTERNAL_URL/api/v4/session | tr ',' '\n' | sed 's/[{}]//g' | awk -F: -v key='"private_token"' '$1==key {print $2}' | tr -d '"')
#Create User
echo "Create Gitlab User: $GITLAB_USER_ID"
curl -H "Private-Token: $GITLAB_ROOT_TOKEN" -H "Content-Type: application/json" -X POST -d "{\"email\":\"$GITLAB_USER_EMAIL\",\"password\":\"$GITLAB_USER_PWD\",\"username\":\"$GITLAB_USER_ID\",\"name\":\"$GITLAB_USER_NAME\",\"confirm\":\"true\"}" $GITLAB_EXTERNAL_URL/api/v4/users
GITLAB_USER_TOKEN=$(curl -d "login=$GITLAB_USER_ID&password=$GITLAB_USER_PWD" $GITLAB_EXTERNAL_URL/api/v4/session | tr ',' '\n' | sed 's/[{}]//g' | awk -F: -v key='"private_token"' '$1==key {print $2}' | tr -d '"')
#Create Project
echo "Create Gitlab Project: $GITLAB_PROJECT_NAME"
GITLAB_PROJECT_ID=$(curl -H "Private-Token: $GITLAB_USER_TOKEN" -H "Content-Type: application/json" -X POST -d "{\"name\":\"$GITLAB_PROJECT_NAME\",\"visibility\":\"internal\"}" $GITLAB_EXTERNAL_URL/api/v4/projects | tr ',' '\n' | awk -F: -v key='{"id"' '$1==key {print $2}' | sed 's/[{}]//g')
GITLAB_PROJECT_URL=$(curl -H "Private-Token: $GITLAB_USER_TOKEN" $GITLAB_EXTERNAL_URL/api/v4/projects/$GITLAB_PROJECT_ID | tr ',' '\n' | sed 's/[{}]//g' | awk -F: -v key='"http_url_to_repo"' '$1==key {for(i=2; i<=NF; i++) printf "%s", $i (i==NF?ORS:OFS)}' | tr -d '"' | tr ' ' ':')
GITLAB_PROJECT_URL_EXTERNAL=$(echo $GITLAB_PROJECT_URL | sed "s/$GITLAB_HELM_RELEASE-gitlab-ce/$PROXY_IP:$GITLAB_URL_NODEPORT/")

#Create WebHook
echo "Create Gitlab Project Webhook"
curl -H "Private-Token: $GITLAB_USER_TOKEN" -H "Content-Type: application/json" -X POST -d "{\"id\":$(date +\"%Y%m%d%H%M%s\"),\"url\":\"$JENKINS_CLUSTER_URL/project/$JENKINS_PROJECT_NAME\",\"push_events\":true,\"enable_ssl_verification\":false}" $GITLAB_EXTERNAL_URL/api/v4/projects/$GITLAB_PROJECT_ID/hooks

#Update .env
echo "Updating .env file"
sed -ie "s/\(^GITLAB_USER=\).*/\1$GITLAB_USER_ID/" .env || echo "GITLAB_USER=$GITLAB_USER_ID" | tee -a .env
sed -ie "s#\(^GITLAB_BASE_URL=\).*#\1$GITLAB_EXTERNAL_URL#" .env || echo "GITLAB_BASE_URL=$GITLAB_EXTERNAL_URL" | tee -a .env
sed -ie "s#\(^GITLAB_IN_CLUSTER_BASE_URL=\).*#\1$GITLAB_CLUSTER_URL#" .env || echo "GITLAB_IN_CLUSTER_BASE_URL=$GITLAB_CLUSTER_URL" | tee -a .env
sed -ie "s/\(^GITLAB_API_TOKEN=\).*/\1\"$GITLAB_USER_TOKEN\"/" .env || echo "GITLAB_API_TOKEN=\"$GITLAB_USER_TOKEN\"" | tee -a .env

sed -ie "s#\(^JENKINS_URL=\).*#\1$JENKINS_EXTERNAL_URL#" .env || echo "JENKINS_URL=$JENKINS_EXTERNAL_URL" | tee -a .env
sed -ie "s#\(^JENKINS_IN_CLUSTER_BASE_URL=\).*#\1$JENKINS_CLUSTER_URL#" .env || echo "JENKINS_IN_CLUSTER_BASE_URL=$JENKINS_CLUSTER_URL" | tee -a .env
sed -ie "s/\(^JENKINS_USER=\).*/\1$JENKINS_USER_ID/" .env || echo "JENKINS_USER=$JENKINS_USER_ID" | tee -a .env
sed -ie "s/\(^JENKINS_USER_API_TOKEN=\).*/\1$JENKINS_USER_API_TOKEN/" .env || echo "JENKINS_USER_API_TOKEN=$JENKINS_USER_API_TOKEN" | tee -a .env

sed -ie "s/\(^JOB_NAME=\).*/\1$JENKINS_PROJECT_NAME/" .env || echo "JOB_NAME=$JENKINS_PROJECT_NAME" | tee -a .env
sed -ie "s/\(^REPO_NAME=\).*/\1$GITLAB_PROJECT_NAME/" .env || echo "REPO_NAME=$GITLAB_PROJECT_NAME" | tee -a .env
sed -ie "s/\(^JENKINS_GIT_USER_CREDENTIAL_ID=\).*/\1$GITLAB_CREDENTIAL_ID/" .env || echo "JENKINS_GIT_USER_CREDENTIAL_ID=$GITLAB_CREDENTIAL_ID" | tee -a .env

ICP_MASTER_IP=$(echo $ICP_URL | awk -F: '{print $2}' | tr -d '/')
sed -ie "s/\(^ICP_MASTER_IP=\).*/\1$ICP_MASTER_IP/" .env || echo "ICP_MASTER_IP=$ICP_MASTER_IP" | tee -a .env
sed -ie "s/\(^K8S_NAMESPACE=\).*/\1$TARGET_NAMESPACE/" .env || echo "K8S_NAMESPACE=$TARGET_NAMESPACE" | tee -a .env

JENKINS_AUTH_FLAG=false
sed -ie "s/\(^JENKIN_PROJECT_ENDPOINT_AUTHENTICATION=\).*/\1$JENKINS_AUTH_FLAG/" .env || echo "JENKIN_PROJECT_ENDPOINT_AUTHENTICATION=$JENKINS_AUTH_FLAG" | tee -a .env
sed -ie "s#\(^COMPILER_DOCKER_IMAGE=\).*#\1$COMPILER_DOCKER_IMAGE#" .env || echo "COMPILER_DOCKER_IMAGE=$COMPILER_DOCKER_IMAGE" | tee -a .env

#Update .env.build
echo "Updating .env.build file"
sed -ie "s/\(^IMAGE_NAME=\).*/\1$DISCOVERY_IMAGE_NAME/" .env.build || echo "IMAGE_NAME=$DISCOVERY_IMAGE_NAME" | tee -a .env.build
sed -ie "s/\(^PRIVATE_DOCKER_REGISTRY_NAME=\).*/\1$REGISTRY_SERVER/" .env.build || echo "PRIVATE_DOCKER_REGISTRY_NAME=$REGISTRY_SERVER" | tee -a .env.build
sed -ie "s/\(^PRIVATE_DOCKER_REGISTRY_PORT=\).*/\1$REGISTRY_PORT/" .env.build || echo "PRIVATE_DOCKER_REGISTRY_PORT=$REGISTRY_PORT" | tee -a .env.build
sed -ie "s/\(^PRIVATE_DOCKER_REGISTRY_IP=\).*/\1$ICP_MASTER_IP/" .env.build || echo "PRIVATE_DOCKER_REGISTRY_IP=$ICP_MASTER_IP" | tee -a .env.build
sed -ie "s/\(^PRIVATE_DOCKER_REGISTRY_NAMESPACE=\).*/\1$TARGET_NAMESPACE/" .env.build || echo "PRIVATE_DOCKER_REGISTRY_NAMESPACE=$TARGET_NAMESPACE" | tee -a .env.build
sed -ie "s/\(^K8S_NAMESPACE=\).*/\1$TARGET_NAMESPACE/" .env.build || echo "K8S_NAMESPACE=$TARGET_NAMESPACE" | tee -a .env.build
sed -ie "s/\(^PROXY_IP=\).*/\1$PROXY_IP/" .env.build || echo "PROXY_IP=$PROXY_IP" | tee -a .env.build

#Update .env.bluemix
sed -ie "s#\(^BLUEMIX_ENDPOINT=\).*#\1$BLUEMIX_ENDPOINT#" .env.bluemix || echo "BLUEMIX_ENDPOINT=$BLUEMIX_ENDPOINT" | tee -a .env.bluemix
sed -ie "s/\(^BLUEMIX_SPACE=\).*/\1$BLUEMIX_SPACE/" .env.bluemix || echo "BLUEMIX_SPACE=$BLUEMIX_SPACE" | tee -a .env.bluemix

#Update .env.cf
sed -ie "s/\(^CF_DOMAIN=\).*/\1$CF_DOMAIN/" .env.cf || echo "CF_DOMAIN=$CF_DOMAIN" | tee -a .env.cf
sed -ie "s/\(^HA_PROXY_IP=\).*/\1$HA_PROXY_IP/" .env.cf || echo "HA_PROXY_IP=$HA_PROXY_IP" | tee -a .env.cf
sed -ie "s/\(^CF_ORG=\).*/\1$CF_ORG/" .env.cf || echo "CF_ORG=$CF_ORG" | tee -a .env.cf
sed -ie "s/\(^CF_SPACE=\).*/\1$CF_SPACE/" .env.cf || echo "CF_SPACE=$CF_SPACE" | tee -a .env.cf

#Push Gitlab Repository
echo "Push code Gitlab Repository"
[ -d .git.old ] && rm -Rf .git.old
[ -d .git ] && mv .git .git.old
git init
git remote add origin $GITLAB_PROJECT_URL_EXTERNAL
[ $? != 0 ] && git remote set-url origin $GITLAB_PROJECT_URL_EXTERNAL
git add *
git add -f .env .env.bluemix .env.build .env.cf
git commit -m 'initial commit'
git push -u origin master

echo "Gitlab Project url: $GITLAB_PROJECT_URL_EXTERNAL"
echo "Login to Jenkins $JENKINS_EXTERNAL_URL (admin:$JENKINS_ADMIN_PWD) , copy admin token and update JENKINS_USER_API_TOKEN in .env.setupci"
