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

import re
import unittest

from kube_utility_container.tests.utility.base import TestBase

class TestEtcdUtilityContainer(TestBase):
    @classmethod
    def setUpClass(cls):
        cls.deployment_name = 'etcdctl-utility'
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
