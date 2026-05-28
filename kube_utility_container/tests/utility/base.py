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

import time
import unittest

from kube_utility_container.services.utility_container_client\
    import UtilityContainerClient
from kube_utility_container.services.dataloader import \
    DeploymentMapping


class TestBase(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.client = UtilityContainerClient()

    def _assert_pod_logs_grew(self, deployment_name, logs_before,
                              timeout=30, interval=2):
        """Poll pod logs until they grow beyond logs_before, then assert."""
        deadline = time.monotonic() + timeout
        logs_after = self.client._get_pod_logs(deployment_name)
        while len(logs_after) <= len(logs_before) and \
                time.monotonic() < deadline:
            time.sleep(interval)
            logs_after = self.client._get_pod_logs(deployment_name)
        self.assertGreater(
            len(logs_after), len(logs_before),
            "Not able to get the latest logs")

    def _get_deployment_name(deployment_name):
        """
        :param deployment_name: if specified the deployment name of
            the utility pod where the utilscli command is
            to be executed.
        :type deployment_name: string
            where the utilscli command is to be executed.
        :return: deployment_name extracted from the deployment
        """
        namesMapping = DeploymentMapping(deployment_name)
        deployment_name = namesMapping._get_mapping_realname()
        return deployment_name
