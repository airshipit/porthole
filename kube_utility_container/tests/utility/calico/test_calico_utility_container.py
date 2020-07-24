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

from kube_utility_container.tests.utility.base import TestBase

class TestCalicoUtilityContainer(TestBase):
    @classmethod
    def setUpClass(cls):
        cls.deployment_name = 'calicoctl-utility'
        super(TestCalicoUtilityContainer, cls).setUpClass()

    def test_verify_calico_client_calicoctl_is_present(self):
        """To verify calico-utility calicoctl is present"""
        exec_cmd = ['utilscli', 'calicoctl', 'version']
        expected = 'Client Version:'
        result_set = self.client.exec_cmd(self.deployment_name, exec_cmd)
        self.assertIn(
            expected, result_set, 'Unexpected value for command: {}, '
            'Command Output: {}'.format(exec_cmd, result_set))

    def test_verify_readonly_rootfs(self):
        """To verify calico-utility readonly rootfs configuration"""
        failures = []
        expected = "False"
        calico_utility_pod = \
            self.client._get_utility_container(self.deployment_name)
        for container in calico_utility_pod.spec.containers:
            if expected != \
                    str(container.security_context.read_only_root_filesystem):
                failures.append(
                    f"container {container.name} is not having expected"
                    f" value {expected} set for read_only_root_filesystem"
                    f" in pod {calico_utility_pod.metadata.name}")
        self.assertEqual(0, len(failures), failures)

    def test_verify_calico_utility_pod_logs(self):
        """To verify calico-utility pod logs"""
        date_1 = (self.client.exec_cmd(
            self.deployment_name,
            ['date', '+%Y-%m-%d %H'])).replace('\n','')
        date_2 = (self.client.exec_cmd(
            self.deployment_name,
            ['date', '+%b %d %H'])).replace('\n','')
        exec_cmd = ['utilscli', 'calicoctl', 'version']
        self.client.exec_cmd(self.deployment_name, exec_cmd)
        pod_logs = (self.client._get_pod_logs(self.deployment_name)). \
            replace('\n','')
        if date_1 in pod_logs:
            latest_pod_logs = (pod_logs.split(date_1))[1:]
        else:
            latest_pod_logs = (pod_logs.split(date_2))[1:]
        self.assertNotEqual(
            0, len(latest_pod_logs), "Not able to get the latest logs")
