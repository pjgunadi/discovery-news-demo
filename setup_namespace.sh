#!/bin/sh

NEW_NAMESPACE=$1
SECRET_NAME=$2
REG_SERVER=$3
REG_PORT=$4
REG_USER=$5
REG_PASSWORD=$6
SVC_ACCOUNT="default"

#Create Namespace
echo "Create $1 namespace"
if ! kubectl get namespace $NEW_NAMESPACE; then
  kubectl create namespace $NEW_NAMESPACE
fi

#Create Secret
echo "Create Kubernetes Secret in $NEW_NAMESPACE namespace"
kubectl -n $NEW_NAMESPACE get secrets $SECRET_NAME
[ $? != 0 ] && kubectl -n $NEW_NAMESPACE create secret docker-registry $SECRET_NAME --docker-server=$REG_SERVER:$REG_PORT --docker-username=$REG_USER --docker-password=$REG_PASSWORD --docker-email=$REG_USER@$REG_SERVER

#Patch Service Account
kubectl -n $NEW_NAMESPACE patch serviceaccount $SVC_ACCOUNT -p "{\"imagePullSecrets\": [{\"name\": \"$SECRET_NAME\"}]}"
