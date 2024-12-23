# Copyright 2020 AT&T Intellectual Property.  All other rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import os
from pathlib import Path

from kube_utility_container.kubecfg.kube_cfg import KubeCfg

from kube_utility_container.services.exceptions import \
    KubeApiException
from kube_utility_container.services.exceptions import \
    KubeConfigException
from kube_utility_container.services.exceptions import \
    KubeDeploymentNotFoundException
from kube_utility_container.services.exceptions import \
    KubeEnvVarException
from kube_utility_container.services.exceptions import \
    KubePodNotFoundException
from kube_utility_container.services.dataloader import \
    DeploymentMapping

from kubernetes import client as kubeclient
from kubernetes import config as kubeconf

from kubernetes.client.rest import ApiException
from kubernetes.stream import stream

from oslo_log import log as logging
from urllib3.exceptions import MaxRetryError

LOG = logging.getLogger(__name__)


class UtilityContainerClient(object):
    """Client to execute utilscli command on utility containers"""

    NAMESPACE = 'utility'

    def __init__(self):
        # Initialize variables
        self._corev1api_client = None
        self._appsv1api_client = None

    @property
    def _corev1api_api_client(self):
        """Property to get the V1CoreAPI client object"""
        if self._corev1api_client:
            return self._corev1api_client
        else:
            try:
                kubeconf.load_kube_config(config_file=self._kubeconfig_file)
                self._corev1api_client = kubeclient.CoreV1Api()
                return self._corev1api_client
            except EnvironmentError as err:
                LOG.exception(
                    'Failed to load Kubernetes config file: {}'.format(err))
                raise KubeConfigException(err)

    @property
    def _appsv1api_api_client(self):
        """Property to get the V1AppsAPI client object"""
        if self._appsv1api_client:
            return self._appsv1api_client
        else:
            try:
                kubeconf.load_kube_config(config_file=self._kubeconfig_file)
                self._appsv1api_client = kubeclient.AppsV1Api()
                return self._appsv1api_client
            except EnvironmentError as err:
                LOG.exception(
                    'Failed to load Kubernetes config file: {}'.format(err))
                raise KubeConfigException(err)

    @property
    def _kubeconfig_file(self):
        """Property to generate kubeconfig file from environment variables"""
        key = 'KUBECONFIG'
        if os.environ.get(key) is not None:
            kube_conf_filename = os.environ.get(key)
        else:
            raise KubeEnvVarException(key)
        if os.path.isfile(kube_conf_filename):
            return kube_conf_filename
        else:
            self._prepare_kube_config(kube_conf_filename)
            return kube_conf_filename

    def _prepare_kube_config(self, kube_conf_filename):
        """Method to generate the kube config file"""
        Path(Path.cwd() / 'etc').mkdir(exist_ok=True)
        Path(kube_conf_filename).touch()
        conf = KubeCfg(kube_conf_filename)
        region_key = 'OS_REGION_NAME'
        kube_server_key = 'KUBE_SERVER'
        if os.environ.get(region_key) is not None:
            server = os.environ.get(kube_server_key)
        else:
            raise KubeEnvVarException(kube_server_key)

        if os.environ.get(region_key) is not None:
            conf.set_cluster(name=os.environ.get(region_key),
                             server=server,
                             insecure_skip_tls_verify=True)
        else:
            raise KubeEnvVarException(region_key)
        username_key = 'OS_USERNAME'
        if os.environ.get(username_key) is not None:
            conf.set_context(name='context_uc',
                             user=os.environ.get(username_key),
                             namespace='utility',
                             cluster=os.environ.get(region_key))
        else:
            raise KubeEnvVarException(username_key)
        conf.use_context('context_uc')
        exec_command_key = 'KUBE_KEYSTONE_AUTH_EXEC'
        if os.environ.get(exec_command_key) is not None:
            conf.set_credentials(
                name=os.environ.get(username_key),
                exec_command=os.environ.get(exec_command_key),
                exec_api_version='client.authentication.k8s.io/v1beta1')
        else:
            raise KubeEnvVarException(exec_command_key)

    def _get_deployment_selectors(self, deployment_name):
        """Method to get the deployment selectors of the deployment queried.

        :param deployment_name: if specified the deployment name of the utility
            pod where the utilscli command is to be executed.
        :type deployment_name: string
            where the utilscli command is to be executed.
        :return: selectors extracted from the deployment
            returned as a string in the format: "key=value, key1=value2..."
        :exception:
            KubeDeploymentNotFoundException -- A custom exception
            KubeDeploymentNotFoundException is raised if no deployment is
            found with the with the parameters namespace and deployment_name
            which is passed as a field_selector.
        """
        # Get a specific deployment by passing the deployment metadata name
        # and the namespace
        deployment = self._appsv1api_api_client.list_namespaced_deployment(
            self.NAMESPACE,
            field_selector='metadata.name={}'.format(deployment_name)).items
        if deployment:
            # Get the selectors from the deployment object returned.
            selector_dict = deployment[0].spec.selector.match_labels
            # Convert the selector dictionary to a string object.
            selectors = ', '.join("{!s}={!s}".format(k, v)
                                  for (k, v) in selector_dict.items())
            return selectors
        else:
            raise KubeDeploymentNotFoundException(
                'Deployment with name {} not found in {} namespace'.format(
                    deployment_name, self.NAMESPACE))

    def _get_utility_container(self, deployment_name):
        """Method to get a specific utility container filtered by the selectors

        :param deployment_name: if specified the deployment name of the utility
            pod where the utilscli command is to be executed.
        :type deployment_name: string
            where the utilscli command is to be executed.
        :return: selectors extracted from the deployment
            utility_container {V1Pod} -- Returns the first pod matched.
        :exception: KubePodNotFoundException -- Exception raised if not pods
            are found.
        """
        namesMapping = DeploymentMapping(deployment_name)
        deployment_name = namesMapping._get_mapping_realname()
        deployment_selectors = self._get_deployment_selectors(deployment_name)
        utility_containers = self._corev1api_api_client.list_namespaced_pod(
            self.NAMESPACE, label_selector=deployment_selectors).items
        if utility_containers:
            return utility_containers[0]
        else:
            raise KubePodNotFoundException(
                'No Pods found in Deployment {} with selectors {} in {} '
                'namespace'.format(deployment_name, deployment_selectors,
                                   self.NAMESPACE))

    def _get_pod_logs(self, deployment_name):
        """Method to get logs for a specific utility pod

        :param deployment_name: if specified the deployment name of
            the utility podwhere the utilscli command is to be executed
        :return: pod logs for specific pod
        """
        pod = self._get_utility_container(deployment_name)
        return self._corev1api_api_client.read_namespaced_pod_log(
            pod.metadata.name, self.NAMESPACE)

    def _get_exec_cmd_output(self, utility_container, ex_cmd, default=1):
        """Exec into a specific utility container, then execute the utilscli
            command and return the output of the command

        :params utility_container: Utility container where the
            utilscli command will be executed.
        :type utility_container: string
        :params ex_cmd: command to be executed inside the utility container
        :type ex_cmd: strings
        :params default: return of cmd_output. optionally can be disabled
        :type integer: 1 (true)
        :type ex_cmd: strings
        :return: Output of command executed in the utility container
        """

        try:
            container = utility_container.spec.containers[0].name
            LOG.info('\nPod Name: {} \nNamespace: {} \nContainer Name: {} '
                     '\nCommand: {}'.format(utility_container.metadata.name,
                                            self.NAMESPACE, container, ex_cmd))
            cmd_output = stream(
                self._corev1api_api_client.connect_get_namespaced_pod_exec,
                utility_container.metadata.name,
                self.NAMESPACE,
                container=container,
                command=ex_cmd,
                stderr=True,
                stdin=False,
                stdout=True,
                tty=False)
            LOG.info('Pod Name: {} Command Output: {}'.format(
                utility_container.metadata.name, cmd_output))
            if default == 1:
                return cmd_output
        except (ApiException, MaxRetryError) as err:
            LOG.exception("An exception occurred in pod "
                          "exec command: {}".format(err))
            raise KubeApiException(err)

    def exec_cmd(self, deployment_name, cmd):
        """Get specific utility container using deployment name, call

        method to execute utilscli command and return the output of
        the command.

        :params deployment_name: deployment name of the utility pod
            where the utilscli command is to be executed.
        :type deployment_name: string
        :params cmd: command to be executed inside the utility container
        :type cmd: strings
        :return: Output of command executed in the utility container
        """

        utility_container = self._get_utility_container(deployment_name)
        return self._get_exec_cmd_output(utility_container, cmd)
