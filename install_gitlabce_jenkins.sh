#!/bin/sh
source .env.setupci

#Login to ICP
CLDCTL=`which cloudctl`
if [ $? == 0 ]; then
  cloudctl login -a $ICP_URL -u $ICP_USER -p $ICP_PWD -n $TARGET_NAMESPACE -c id-${CLUSTER_NAME}-account --skip-ssl-validation
else
  echo "1" | bx pr login -a $ICP_URL -u $ICP_USER -p $ICP_PWD --skip-ssl-validation
  sleep 2
  bx pr cluster-config $CLUSTER_NAME
fi

#Check Helm Version
HELM_VERSION=$(kubectl -n kube-system get deploy tiller-deploy -o=jsonpath='{.spec.template.spec.containers[0].image}' | awk -F: '{print $NF}')

#Extract TLS Certificate
TLS_ENABLED=$(kubectl -n kube-system get deploy tiller-deploy -o=jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="TILLER_TLS_ENABLE")].value}')
if [ "$TLS_ENABLED" == "1" ]; then
  if [[ $HELM_VERSION != *"-icp" ]]; then
    CA_CRT="tiller.ca.pem"
    kubectl -n kube-system get secret tiller-secret -o=jsonpath='{.data.ca\.crt}' | base64 --decode | tee $CA_CRT
    TLS_CRT="tiller.cert.pem"
    kubectl -n kube-system get secret tiller-secret -o=jsonpath='{.data.tls\.crt}' | base64 --decode | tee $TLS_CRT
    TLS_KEY="tiller.key.pem"
    kubectl -n kube-system get secret tiller-secret -o=jsonpath='{.data.tls\.key}' | base64 --decode | tee $TLS_KEY
  fi
fi

helm repo update

#Update TLS Certificate set TLS_SUFFIX
if [ "$TLS_ENABLED" == "1" ]; then
  if [[ $HELM_VERSION = *"-icp" ]]; then
    TLS_SUFFIX="--tls"
  else
    TLS_SUFFIX="--tls --tls-ca-cert $CA_CRT --tls-cert $TLS_CRT --tls-key $TLS_KEY"
  fi
fi

#Apply Image Policy
#POLICIES=$(kubectl -n $TARGET_NAMESPACE get imagepolicies | awk 'FNR > 1 {print $1}')
kubectl apply -n $TARGET_NAMESPACE -f image-policy.yaml

#Install Gitlab and Jenkins Helm Chart
if [ "$DELETE_EXISTING_CHART" == "1" ]; then
  [ "$(helm list $GITLAB_HELM_RELEASE $TLS_SUFFIX)" != "" ] && helm delete $GITLAB_HELM_RELEASE --purge $TLS_SUFFIX
  [ "$(helm list $JENKINS_HELM_RELEASE $TLS_SUFFIX)" != "" ] && helm delete $JENKINS_HELM_RELEASE --purge $TLS_SUFFIX
fi

[ "$(helm list $GITLAB_HELM_RELEASE $TLS_SUFFIX)" == "" ] && helm install --name $GITLAB_HELM_RELEASE --namespace $GITLAB_NAMESPACE --set externalUrl=http://$GITLAB_HELM_RELEASE-gitlab-ce,gitlabRootPassword=$GITLAB_ROOT_PASSWORD stable/gitlab-ce $TLS_SUFFIX
[ "$(helm list $JENKINS_HELM_RELEASE $TLS_SUFFIX)" == "" ] && helm install --name $JENKINS_HELM_RELEASE --namespace $GITLAB_NAMESPACE --set Master.Image=jenkins/jenkins --set Master.ImageTag=lts --set Master.AdminUser="$JENKINS_USER_ID" --set Master.AdminPassword="$JENKINS_USER_PWD" --set Master.InstallPlugins={kubernetes:1.12.6\,workflow-aggregator:2.5\,workflow-job:2.25\,credentials-binding:1.16\,git:3.9.1\,gitlab-plugin:1.5.10} --set Agent.Image=jenkins/jnlp-slave --set Agent.ImageTag="" --set rbac.install=true stable/jenkins $TLS_SUFFIX
