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

class TestOpenstackUtilityContainer(TestBase):
    @classmethod
    def setUpClass(cls):
        cls.deployment_name = 'openstack-utility'
        super(TestOpenstackUtilityContainer, cls).setUpClass()

    def test_verify_readonly_rootfs(self):
        """To verify openstack-utility readonly rootfs configuration"""
        failures = []
        expected = "False"
        openstack_utility_pod = \
            self.client._get_utility_container(self.deployment_name)
        for container in openstack_utility_pod.spec.containers:
            if expected != \
                    str(container.security_context.read_only_root_filesystem):
                failures.append(
                    f"container {container.name} is not having expected"
                    f" value {expected} set for read_only_root_filesystem"
                    f" in pod {openstack_utility_pod.metadata.name}")
        self.assertEqual(0, len(failures), failures)
