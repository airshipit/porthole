#!/usr/bin/python
{{/*
Copyright 2019 The Openstack-Helm Authors.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/}}
# PBR Generated from u'console_scripts'
import sys
import os
import logging
#import getpass
from oslo_rootwrap.cmd import main

exec_name = sys.argv[0]
host_name = os.environ.get("HOSTNAME")
log_level = {{ .Values.conf.computerootwrapconf.DEFAULT.syslog_log_level | quote }}
facility = {{ .Values.conf.computerootwrapconf.DEFAULT.syslog_log_facility | quote }}

if "AUSER" in os.environ:
    user_id = os.environ["AUSER"]
elif {{ .Values.conf.utility.always_log_user | quote }} == 'true':
    os.environ["AUSER"] = "development site" #getpass.getuser()
    user_id = os.environ["AUSER"]
else:
    print("No username set in AUSER environment variable, for security reasons access restricted from connecting to container.")
    exit()

try:
    handler = logging.handlers.SysLogHandler(address='/dev/log',facility=facility)
except IOError:
    print("Unable to setup logging, for security reasons access restricted from connecting to container.")
    exit()

formatter = logging.Formatter('%(asctime)s ' + host_name + ' ' + '%(levelname)s' +
    os.path.basename(exec_name) + ': ' + 'ActualUser=' + user_id + ': %(message)s')
handler.setFormatter(formatter)
root = logging.getLogger()
root.setLevel(log_level)
root.addHandler(handler)

if __name__ == "__main__":
    sys.exit(main())

