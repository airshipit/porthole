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
import re
import os

from kube_utility_container.tests.utility.base import TestBase

node = os.uname().nodename

class TestComputeUtilityContainer(TestBase):
    @classmethod
    def setUpClass(cls):
        cls.deployment_name = 'compute-utility'
        super(TestComputeUtilityContainer, cls).setUpClass()

    @unittest.expectedFailure
    def test_verify_compute_ovsclient_is_present(self):
        """To verify compute-utility ovs-client is present."""
        cmd = 'ovs-client '
        exec_cmd = ['utilscli', cmd + node, 'ovs-vsctl -V']
        expected = 'ovs-vsctl'
        result_set = self.client.exec_cmd(self.deployment_name, exec_cmd)
        self.assertIn(
            expected, result_set, 'Unexpected value for command: {}, '
            'Command Output: {}'.format(exec_cmd, result_set))

    @unittest.expectedFailure
    def test_verify_compute_libvirtclient_is_present_on_host(self):
        """To verify compute-utility Libvirt-client is present."""
        cmd = 'libvirt-client '
        exec_cmd = ['utilscli', cmd + node, 'virsh list']
        expected = 'Id'
        result_set = self.client.exec_cmd(self.deployment_name, exec_cmd)
        self.assertIn(
            expected, result_set, 'Unexpected value for command: {}, '
            'Command Output: {}'.format(exec_cmd, result_set))
