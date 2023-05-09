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

from kubeconfig import KubeConfig


class KubeCfg(KubeConfig):
    """This class inherits from the KubeConfig module. It overides the

    set_credentials method to add the user exec parameters to the kube config
    file that is generated.
    """

    def set_credentials(self,
                        name,
                        auth_provider=None,
                        auth_provider_args=None,
                        client_certificate=None,
                        client_key=None,
                        embed_certs=None,
                        password=None,
                        token=None,
                        username=None,
                        exec_command=None,
                        exec_api_version=None,
                        exec_arg=None,
                        exec_env=None):
        """Creates or updates a ``user`` entry under the ``users`` entry.

        In the case where you are updating an existing user, only the optional
        keyword args that you pass in will be updated on the entry.

        :param str name: The name of the user to add or update.
        :param str auth_provider: The auth provider name to use. For example,
            ``oidc``, ``gcp``, etc.
        :param dict auth_provider_args: Some providers support extra config
            params, which can be passed in as a flat dict.
        :param str client_certificate: Path to your X.509 client cert (if
            using cert auth).
        :param str client_key: Path to your cert's private key (if using
            cert auth).
        :param bool embed_certs: Combined with ``client_certificate``,

            setting this to ``True`` will cause the cert to be embedded
            directly in the written config. If ``False`` or unspecified,
            the path to the cert will be used instead.
        :param str username: Your username (if using basic auth).
        :param str password: Your user's password (if using basic auth).
        :param str token: Your private token (if using token auth).
        :param str exec_command: The command executable name to use. For
        example, ``client-keystone-auth``
        :param str exec_api_version: The api version to use. For example,
            ``client.authentication.k8s.io/v1beta1``
        """
        flags = []
        if auth_provider is not None:
            flags += ['--auth-provider=%s' % auth_provider]
        if auth_provider_args is not None:
            arg_pairs = [
                "%s=%s" % (k, v) for k, v in auth_provider_args.items()
            ]
            for arg_pair in arg_pairs:
                flags += ['--auth-provider-arg=%s' % arg_pair]
        if client_certificate is not None:
            flags += ['--client-certificate=%s' % client_certificate]
        if client_key is not None:
            flags += ['--client-key=%s' % client_key]
        if embed_certs is not None:
            flags += ['--embed-certs=%s' % self._bool_to_cli_str(embed_certs)]
        if password is not None:
            flags += ['--password=%s' % password]
        if token is not None:
            flags += ['--token=%s' % token]
        if username is not None:
            flags += ['--username=%s' % username]
        if exec_command is not None:
            flags += ['--exec-command=%s' % exec_command]
        if exec_api_version is not None:
            flags += ['--exec-api-version=%s' % exec_api_version]
        if exec_arg is not None:
            flags += ['--exec-arg=%s' % exec_arg]
        if exec_env is not None:
            arg_pairs = ["%s=%s" % (k, v) for k, v in exec_env.items()]
            for arg_pair in arg_pairs:
                flags += ['--exec-env=%s' % arg_pair]
        self._run_kubectl_config('set-credentials', name, *flags)
