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

class TestPostgresqlUtilityContainer(TestBase):
    @classmethod
    def setUpClass(cls):
        cls.deployment_name = 'postgresql-utility'
        super(TestPostgresqlUtilityContainer, cls).setUpClass()

    def test_verify_apparmor(self):
        """To verify postgresql-utility Apparmor"""
        failures = []
        expected = "runtime/default"
        postgresql_utility_pod = \
            self.client._get_utility_container(self.deployment_name)
        for container in postgresql_utility_pod.spec.containers:
            annotations_common = \
                'container.apparmor.security.beta.kubernetes.io/'
            annotations_key = annotations_common + container.name
            if expected != postgresql_utility_pod.metadata.annotations[
                    annotations_key]:
                failures.append(
                    f"container {container.name} belongs to pod "
                    f"{postgresql_utility_pod.metadata.name} "
                    f"is not having expected apparmor profile set")
        self.assertEqual(0, len(failures), failures)
