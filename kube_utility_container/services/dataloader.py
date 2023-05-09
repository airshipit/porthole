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

import json
import os


class DeploymentMapping():
    """ Class to handle custom deployment names different than the defaults
    set in AVT unittests.  When actual mapping file exists, it will search
     and return on "real_name" defined in cfgmap variable.
    """

    def __init__(self, name):
        self.raw_deployment_name = name
        self.cfgmap = 'etc/deployment_name_mappings.json'

    def _get_mapping_realname(self):
        """ Method to return real deployment name when a config map file is
        explicitly defined.  Otherwise, raw deployment name is been used.

        : param name: the actual deployment name (raw) source from
            the running unittest cases
        :cfgmap variable: set to the location of map configuration file in
            json format.
        : return: return the actual/real deployment name in either case

        If the real deployment_names are different than the actual/raw
            deployment names,
        they can be mapped by defining the entries in
            etc/deployment_name_mappings.json like example below.

        Example:
        {
          "comments":
            "deployment names mapping samples. update it accordingly",
          "mappings": [
            {
              "raw_name": "mysqlclient-utility",
              "real_name": "clcp-mysqlclient-utility"
            },
            {
              "raw_name": "etcdctl-utility",
              "real_name": "clcp-etcdctl-utility"
            }
          ]
        }
        """

        if os.path.exists(self.cfgmap):
            fh = open(self.cfgmap, "r")
            data = json.load(fh)
            fh.close()

            for item in data['mappings']:
                if item['raw_name'] == self.raw_deployment_name:
                    return item['real_name']
                    break
        else:
            return self.raw_deployment_name

    def _is_deployment_name_consistent(self, actual_name):
        """ Verify deployment names are consistent when
            set with configuration mapping
        """
        if os.path.exists(self.cfgmap):
            fh = open(self.cfgmap, "r")
            data = json.load(fh)
            fh.close()

            for item in data['mappings']:
                if item['real_name'] == actual_name:
                    return True
                else:
                    continue
                    return False
        else:
            return True

    def _use_default_deployment_names(self):
        """ Return default deployment names when no mapping is set"""
        if os.path.exists(self.cfgmap):
            return False
        else:
            return True
