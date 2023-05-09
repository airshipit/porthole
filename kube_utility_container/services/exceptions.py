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


class KubeUtilityContainerException(Exception):
    """Class for Kube Utility Container Plugin Exceptions"""

    def __init__(self, error="", message=""):
        self.error = error or self.__class__.error
        self.message = message or self.__class__.message
        super(KubeUtilityContainerException,
              self).__init__(''.join([self.error, '::', self.message]))


class KubeConfigException(Exception):
    """Exception class when Kubernetes config is not found"""

    def __init__(self, message):
        self.message = "Kubernetes config not found: {}".format(message)
        super(KubeConfigException, self).__init__(self.message)


class KubeApiException(Exception):
    """Exception class for error in accessing Kubernetes APIs"""

    def __init__(self, message):
        self.message = "Exception occurred while accessing Kubernetes APIs: " \
                       "{}".format(message)
        super(KubeApiException, self).__init__(self.message)


class KubeDeploymentNotFoundException(Exception):
    """Exception class for Kube Deployment not found in a namespace"""

    def __init__(self, message):
        self.message = "Deployment not found Error: {}".format(message)
        super(KubeDeploymentNotFoundException, self).__init__(self.message)


class KubePodNotFoundException(Exception):
    """Exception class for specific utility pod not found in running state"""

    def __init__(self, message):
        self.message = "Pod not found: {}".format(message)
        super(KubePodNotFoundException, self).__init__(self.message)


class KubeEnvVarException(Exception):
    """Exception class for environment variable not set."""

    def __init__(self, message):
        self.message = "Environment Variable Not Found: {}".format(message)
        super(KubeEnvVarException, self).__init__(self.message)
