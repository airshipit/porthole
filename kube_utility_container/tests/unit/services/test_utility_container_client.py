# Copyright 2020 AT&T Intellectual Property.  All other rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

from kubernetes import client
import unittest

from unittest.mock import MagicMock as Mock
from unittest.mock import patch

from kube_utility_container.services.exceptions import \
    KubeDeploymentNotFoundException
from kube_utility_container.services.exceptions import \
    KubeEnvVarException
from kube_utility_container.services.exceptions import \
    KubePodNotFoundException
from kube_utility_container.services.utility_container_client import \
    UtilityContainerClient


class TestUtilityContainerClient(unittest.TestCase):
    """Unit tests for Utility Container Client"""

    @patch('kube_utility_container.services.utility_container_client.'
           'UtilityContainerClient._get_utility_container')
    @patch('kube_utility_container.services.utility_container_client.'
           'UtilityContainerClient._get_exec_cmd_output')
    def test_exec_cmd(self, mock_get_exec_cmd_output, mock_utility_container):
        v1_container_obj = Mock(
            spec=client.V1Container(
                name='ceph_utility', image='sha', image_pull_policy='Always'))
        v1_spec_obj = Mock(spec=client.V1PodSpec(containers=v1_container_obj))
        v1_meta_obj = Mock(
            spec=client.V1ObjectMeta(
                name='clcp-ceph-utility-5454794df8-xqwj5', labels='app=ceph'))

        v1_pod_obj = Mock(
            spec=client.V1Pod(
                api_version='v1', metadata=v1_meta_obj, spec=v1_spec_obj))
        mock_utility_container.return_value = v1_pod_obj
        mock_get_exec_cmd_output.return_value = "Health OK"

        utility_container_client = UtilityContainerClient()
        response = utility_container_client.exec_cmd(
            'clcp-utility', ['utilscli', 'ceph', 'status'])

        self.assertIsNotNone(response)
        self.assertIsInstance(response, str)
        self.assertEqual(response, mock_get_exec_cmd_output.return_value)

    @patch('kube_utility_container.services.utility_container_client.'
           'UtilityContainerClient._get_utility_container',
           side_effect=KubePodNotFoundException('utility'))
    def test_exec_cmd_no_utility_pods_returned(self, mock_list_pods):
        mock_list_pods.return_value = []
        utility_container_client = UtilityContainerClient()
        with self.assertRaises(KubePodNotFoundException):
            utility_container_client.exec_cmd('clcp-utility',
                                              ['utilscli', 'ceph', 'status'])

    @patch('kube_utility_container.services.utility_container_client.'
           'UtilityContainerClient._get_deployment_selectors',
           side_effect=KubeDeploymentNotFoundException('utility'))
    @patch('kube_utility_container.services.utility_container_client.'
           'UtilityContainerClient._corev1api_api_client')
    def test_exec_cmd_no_deployments_returned(self, deployment, api_client):
        deployment.return_value = []
        api_client.return_value = []
        utility_container_client = UtilityContainerClient()
        with self.assertRaises(KubeDeploymentNotFoundException):
            utility_container_client.exec_cmd('clcp-ceph-utility',
                                              ['utilscli', 'ceph', 'status'])

    @patch('kube_utility_container.services.utility_container_client.'
           'UtilityContainerClient._get_deployment_selectors',
           side_effect=KubeEnvVarException('utility'))
    @patch('kube_utility_container.services.utility_container_client.'
           'UtilityContainerClient._appsv1api_api_client',
           side_effect=KubeEnvVarException('KUBECONFIG'))
    def test_env_var_kubeconfig_not_set_raises_exception(
            self, deployment, api_client):
        deployment.return_value = []
        api_client.return_value = []
        utility_container_client = UtilityContainerClient()
        with self.assertRaises(KubeEnvVarException):
            utility_container_client.exec_cmd('clcp-ceph-utility',
                                              ['utilscli', 'ceph', 'status'])
