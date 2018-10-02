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
HELM_VERSION=$(kubectl -n kube-system get deploy tiller-deploy -o=jsonpath='{.spec.template.spec.containers[0].image}' | awk -F: '{print $2}')

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

#Install Helm Client
OSNAME=$(uname | tr '[:upper:]' '[:lower:]')
HELM_PATH=$(which helm)
if [ $? != 0 ]; then
  if [[ $HELM_VERSION = *"-icp" ]]; then
    curl -k -O $ICP_URL/helm-api/cli/$OSNAME-amd64/helm
    [ -x helm ] || chmod +x helm
    echo "Install helm version $HELM_VERSION"
    mv helm /usr/local/bin/
    helm init --client-only --home ~/.helm-icp
    bx pr cluster-config $CLUSTER_NAME
  else
    curl -O https://kubernetes-helm.storage.googleapis.com/helm-$HELM_VERSION-$OSNAME-amd64.tar.gz
    tar -zxvf helm-$HELM_VERSION-$OSNAME-amd64.tar.gz $OSNAME-amd64/helm
    echo "Install helm version $HELM_VERSION"
    mv $OSNAME-amd64/helm /usr/local/bin/
    helm init --client-only
  fi
else
  HELM_CLIENT_VER=$(helm version --client | tr ',' '\n' | awk -F: 'NR==1 {print $NF}' | tr -d [\"] | tr '+' '-')
  if [ "$HELM_CLIENT_VER" != "$HELM_VERSION" ]; then
    if [[ $HELM_VERSION = *"-icp" ]]; then
      curl -k -O $ICP_URL/helm-api/cli/$OSNAME-amd64/helm
      [ - helm ] || chmod +x helm
      echo "Moving old helm to $HELM_PATH.$HELM_CLIENT_VER"
      mv $HELM_PATH $HELM_PATH.$HELM_CLIENT_VER
      echo "Install helm version $HELM_VERSION"
      mv helm /usr/local/bin/
      helm init --client-only --home ~/.helm-icp
      bx pr cluster-config $CLUSTER_NAME
    else
      curl -O https://kubernetes-helm.storage.googleapis.com/helm-$HELM_VERSION-$OSNAME-amd64.tar.gz
      tar -zxvf helm-$HELM_VERSION-$OSNAME-amd64.tar.gz $OSNAME-amd64/helm
      echo "Moving old helm to $HELM_PATH.$HELM_CLIENT_VER"
      mv $HELM_PATH $HELM_PATH.$HELM_CLIENT_VER
      echo "Install helm version $HELM_VERSION"
      mv $OSNAME-amd64/helm $(dirname "$HELM_PATH")
      helm init --client-only
    fi
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
