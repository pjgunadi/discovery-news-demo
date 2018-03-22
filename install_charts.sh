#!/bin/sh
source .env.setupci

#Login to ICP
echo "1" | bx pr login -a $ICP_URL -u $ICP_USER -p $ICP_PWD --skip-ssl-validation
sleep 2
bx pr cluster-config $CLUSTER_NAME

#Install Helm Client
HELM_PATH=$(which helm)
if [ $? != 0 ]; then
    curl -O https://kubernetes-helm.storage.googleapis.com/helm-$HELM_VERSION-darwin-amd64.tar.gz
    tar -zxvf $HELM_VERSION-darwin-amd64.tar.gz darwin-amd64/helm
    mv darwin-amd64/helm /usr/local/bin/
    helm init --client-only
fi
helm repo update

#Install Gitlab and Jenkins Helm Chart
#[ "$(helm list $GITLAB_HELM_RELEASE)" != "" ] && helm delete $GITLAB_HELM_RELEASE --purge
#[ "$(helm list $JENKINS_HELM_RELEASE)" != "" ] && helm delete $JENKINS_HELM_RELEASE --purge

[ "$(helm list $GITLAB_HELM_RELEASE)" == "" ] && helm install --name $GITLAB_HELM_RELEASE --namespace $GITLAB_NAMESPACE --set externalUrl=http://$GITLAB_HELM_RELEASE-gitlab-ce,gitlabRootPassword=$GITLAB_ROOT_PASSWORD stable/gitlab-ce
[ "$(helm list $JENKINS_HELM_RELEASE)" == "" ] && helm install --name $JENKINS_HELM_RELEASE --namespace $GITLAB_NAMESPACE --set Master.Image=jenkins/jenkins --set Master.ImageTag=lts --set Master.InstallPlugins={kubernetes:1.3.3\,workflow-aggregator:2.5\,workflow-job:2.17\,credentials-binding:1.15\,git:3.8.0\,gitlab-plugin:1.5.3} --set Agent.Image=jenkins/jnlp-slave --set Agent.ImageTag="" --set rbac.install=true stable/jenkins
