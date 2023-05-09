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

import unittest

from kube_utility_container.services.dataloader \
    import DeploymentMapping


class TestDeploymentNameMapping(unittest.TestCase):
    """Unit tests for Utility Service Data Loader
        Verify deployment name is consistent with the mapping.
        Otherwise, no change. Default deployment names are used.
    """

    def setUp(self) -> None:
        self.mapping = DeploymentMapping(self)

    def tearDown(self) -> None:
        pass

    def test_deployment_name_is_consistent_with_name_mapping(self):
        """ Verify the correct deployment names is returned when mapping
                has been used
        """
        self.assertTrue(
            self.mapping._is_deployment_name_consistent("clcp-etcd-utility"))

    def test_deployment_name_use_the_defaults(self):
        """ Check if default deployment names are been used."""
        self.assertTrue(self.mapping._use_default_deployment_names())
