#!/bin/bash

# Script installs Kubectl latest binary and K8S-Keystone-Auth provider.
# It will generate a default 'kubectl' configuration file for the user with the appropriate
# settings to remotely connect to K8S cluster through Keystone authentication mechanism.


if [[ ${#} -lt 2 ]] ; then
  echo "Abort - Usage $0 <SITE NAME> <USER_ID> <NAMESPACE>"
  exit 1
fi

SITE_NAME=$1 ; LOGNAME=$2 ; NAMESPACE=$3

LOGNAME_GRP=$(grep ${LOGNAME} /etc/passwd |cut -d":" -f3)

# set default env variables
: ${USER_HOME:=$HOME}
: ${USER_KUBECFG:=$USER_HOME/.kube/config}

function _addSourceList() {
  echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | \
     tee -a /etc/apt/sources.list.d/kubernetes.list
  curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
  apt-get update
}

# Install dependencies once
function _installDep () {

   # kubectl
   if [[ $1 == 'kubectl' ]] ; then
      echo "Installing [${1}] dependency required..."
      apt-get install -y kubectl
   fi
}

# Create kubeconfig skelton file
function _createConfig() {
    tee ${USER_KUBECFG} <<EOF
---
apiVersion: v1
namespace: ${NAMESPACE}

# Authentication via API WebHook Ingress service endpoint
clusters:
- cluster:
    server: https://<WEBHOOK-API-INGRESS-FQDN>
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: ${LOGNAME}
  name: ${LOGNAME}@kubernetes
current-context: ${LOGNAME}@kubernetes
kind: Config
preferences: {}
users:
- name: ${LOGNAME}
  user:
    exec:
      command: "/usr/local/uc/bin/client-keystone-auth"
      apiVersion: "client.authentication.k8s.io/v1beta1"

      env:
      - name: "OS_DOMAIN_NAME"
        value: default
      - name: "OS_INTERFACE"
        value: public
      - name: "OS_USERNAME"
        value: ${LOGNAME}
      - name: "OS_PASSWORD"
        value: "<USER-PASSWORD>"
      - name: "OS_PROJECT_NAME"
        value: admin
      - name: "OS_REGION_NAME"
        value: ${SITE_NAME}
      - name: "OS_IDENTITY_API_VERSION"
        value: "3"

      args:
      - "--keystone-url=<UCP-KEYSTONE-INGRESS-FQDN>/v3"

EOF
}

# checking and installing 'kubectl'
if [[ ! -x /usr/bin/kubectl ]] ; then
   echo "[Kubectl binary] is not found on this system.."
   echo "Checking user[${LOGNAME}] sudo ability"
   let num=$(id -u)
   if [ $num -ne '0' ]; then
      echo "Abort dependencies installation. You [$LOGNAME] are not root yet"
      exit 1
   else
      echo "Looking good. You [$LOGNAME] are root now"
      _addSourceList
      _installDep "kubectl"
   fi
fi

if [[ ! -d ${USER_HOME}/.kube ]]; then
   mkdir ${USER_HOME}/.kube
   chown -R ${LOGNAME}:${LOGNAME_GRP} ${USER_HOME}/.kube
fi

# create config if it does not exit
if [[ ! -f ${USER_KUBECFG} ]]; then
   _createConfig
   chown ${LOGNAME}:${LOGNAME_GRP} ${USER_HOME}/.kube/config
fi

# staging uc functions to a common area
if [[ ! -d /usr/local/uc/bin/ ]]; then
   mkdir -p /usr/local/uc/bin/
   cp -p funs_uc.sh /usr/local/uc/bin/
   echo "Installing [k8s-keystone-authentication] component"
   curl -SL# https://api.nz-por-1.catalystcloud.io:8443/v1/AUTH_b23a5e41d1af4c20974bf58b4dff8e5a/lingxian-public/client-keystone-auth \
           -o /usr/local/uc/bin/client-keystone-auth
   chmod 755 -R /usr/local/uc
   chown root:root -R /usr/local/uc
fi

# Update user bash rc script to include uc funcions
if [[ -f ${HOME}/.bashrc ]]; then
   cp -p ${HOME}/.bashrc ${HOME}/.bashrc.jmp.bck.$(date +%s)
   egrep funs_uc ${HOME}/.bashrc
   if [[ $? -eq '1' ]] ; then
     tee -a ${HOME}/.bashrc <<EOF
# Utility container common functions
if [[ -f /usr/local/uc/bin/funs_uc.sh ]]; then
  . /usr/local/uc/bin/funs_uc.sh
fi
EOF
   fi
fi