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

import unittest

from unittest.mock import patch

from kube_utility_container.services.exceptions import \
    KubePodNotFoundException
from kube_utility_container.services.utility_container_client import \
    UtilityContainerClient

from kube_utility_container.tests.utility.base import TestBase


class TestEtcdUtilityContainer(TestBase):

    @classmethod
    def setUpClass(cls):
        cls.deployment_name = cls._get_deployment_name("etcdctl-utility")
        super(TestEtcdUtilityContainer, cls).setUpClass()

    def test_verify_etcd_ctl_is_present(self):
        """To verify etcdctl-utility etcdctl is present."""
        exec_cmd = ['utilscli', 'etcdctl', 'version']
        expected = 'etcdctl version:'
        result_set = self.client.exec_cmd(self.deployment_name, exec_cmd)
        self.assertIn(
            expected, result_set, 'Unexpected value for command: {}, '
            'Command Output: {}'.format(exec_cmd, result_set))

    @unittest.expectedFailure
    def test_verify_etcd_endpoint_is_healthy(self):
        """To verify etcdctl-utility endpoint is healthy"""
        exec_cmd = ['utilscli', 'etcdctl', 'endpoint health']
        expected = 'is health: successfully'
        result_set = self.client.exec_cmd(self.deployment_name, exec_cmd)
        self.assertIn(
            expected, result_set, 'Unexpected value for command: {}, '
            'Command Output: {}'.format(exec_cmd, result_set))

    def test_verify_apparmor(self):
        """To verify etcdctl-utility Apparmor"""
        failures = []
        expected = "runtime/default"
        etcdctl_utility_pod = \
            self.client._get_utility_container(self.deployment_name)
        for container in etcdctl_utility_pod.spec.containers:
            annotations_common = \
                'container.apparmor.security.beta.kubernetes.io/'
            annotations_key = annotations_common + container.name
            if expected != etcdctl_utility_pod.metadata.annotations[
                    annotations_key]:
                failures.append(f"container {container.name} belongs to pod "
                                f"{etcdctl_utility_pod.metadata.name} "
                                f"is not having expected apparmor profile set")
        self.assertEqual(0, len(failures), failures)

    def test_verify_readonly_rootfs(self):
        """To verify etcdctl-utility readonly rootfs configuration"""
        failures = []
        expected = "False"
        etcdctl_utility_pod = \
            self.client._get_utility_container(self.deployment_name)
        for container in etcdctl_utility_pod.spec.containers:
            if expected != \
                    str(container.security_context.read_only_root_filesystem):
                failures.append(
                    f"container {container.name} is not having expected"
                    f" value {expected} set for read_only_root_filesystem"
                    f" in pod {etcdctl_utility_pod.metadata.name}")
        self.assertEqual(0, len(failures), failures)

    def test_verify_etcdctl_utility_pod_logs(self):
        """To verify etcdctl-utility pod logs"""
        date_1 = (self.client.exec_cmd(self.deployment_name,
                                       ['date', '+%Y-%m-%d %H'])).replace(
                                           '\n', '')
        date_2 = (self.client.exec_cmd(self.deployment_name,
                                       ['date', '+%b %d %H'])).replace(
                                           '\n', '')
        exec_cmd = ['utilscli', 'etcdctl', 'version']
        self.client.exec_cmd(self.deployment_name, exec_cmd)
        pod_logs = (self.client._get_pod_logs(self.deployment_name)). \
            replace('\n', '')
        if date_1 in pod_logs:
            latest_pod_logs = (pod_logs.split(date_1))[1:]
        else:
            latest_pod_logs = (pod_logs.split(date_2))[1:]
        self.assertNotEqual(0, len(latest_pod_logs),
                            "Not able to get the latest logs")

    @patch(
        'kube_utility_container.services.utility_container_client.'
        'UtilityContainerClient._get_utility_container',
        side_effect=KubePodNotFoundException('utility'))
    def test_exec_cmd_no_etcdctl_utility_pods_returned(self, mock_list_pods):
        mock_list_pods.return_value = []
        utility_container_client = UtilityContainerClient()
        exec_cmd = ['utilscli', 'etcdctl', 'version']
        with self.assertRaises(KubePodNotFoundException):
            utility_container_client.exec_cmd(self.deployment_name, exec_cmd)
