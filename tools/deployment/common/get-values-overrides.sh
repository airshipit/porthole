#!/bin/bash
#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.

# Resolve Helm values overrides for a set of features.
#
# This replaces `helm osh get-values-overrides` from the standalone
# openstack-helm-plugin repo, reimplementing its semantics so porthole no
# longer needs the plugin installed.
#
# Usage: get-values-overrides.sh [-p path] [-s subchart] -c chart <feature>...
#
#   -p  base path holding the overrides tree (default: cwd)
#   -c  chart to get the overrides for (required)
#   -s  subchart to get the overrides for (optional)
#
# If 3 features are passed, the overrides are looked up in this order:
#
#   <path>/<chart>/<feature-3>.yaml
#   <path>/<chart>/<feature-2>.yaml
#   <path>/<chart>/<feature-2>-<feature-3>.yaml
#   <path>/<chart>/<feature-1>.yaml
#   <path>/<chart>/<feature-1>-<feature-3>.yaml
#   <path>/<chart>/<feature-1>-<feature-2>.yaml
#   <path>/<chart>/<feature-1>-<feature-2>-<feature-3>.yaml
#
# Thinking of the features as bits of a binary number where <feature-3> is the
# least significant bit, the order corresponds to all numbers from 001 to 111.
#
# Every candidate that exists is emitted as `--values <file>` on stdout, in
# that order, so later (more specific) overrides win. Diagnostics go to stderr
# so the caller can safely use $(...) around this script. The plugin's
# --download/--url behaviour is intentionally not carried over: the gate has
# the overrides checked out locally and silently fetching values from the
# internet mid-deploy is not something we want.

set -eo pipefail

base_path="$(pwd)"
chart=""
subchart=""

while getopts ":p:c:s:h" opt; do
    case "${opt}" in
        p) base_path="${OPTARG}" ;;
        c) chart="${OPTARG}" ;;
        s) subchart="${OPTARG}" ;;
        h) sed -n '15,42p' "$0" >&2; exit 0 ;;
        \?) echo "Unknown option: -${OPTARG}" >&2; exit 1 ;;
        :) echo "Option -${OPTARG} requires an argument" >&2; exit 1 ;;
    esac
done
shift $((OPTIND - 1))

if [ -z "${chart}" ]; then
    echo "-c <chart> is required" >&2
    exit 1
fi

features=("$@")
n=${#features[@]}
if [ "${n}" -eq 0 ]; then
    echo "No features provided" >&2
    exit 0
fi

override_dir="${base_path}/${chart}"
[ -n "${subchart}" ] && override_dir="${override_dir}/${subchart}"

echo "Base path: ${base_path}" >&2
echo "Chart: ${chart}" >&2
[ -n "${subchart}" ] && echo "Subchart: ${subchart}" >&2
echo "Features: ${features[*]}" >&2

# Reverse the feature list so that bit 0 is the last feature given, matching
# the plugin's ordering.
rev=()
for ((i = n - 1; i >= 0; i--)); do
    rev+=("${features[i]}")
done

args=()
for ((num = 1; num < (1 << n); num++)); do
    words=()
    # Descending bit order turns e.g. {a,c} back into "a-c", the order the
    # features were given in.
    for ((i = n - 1; i >= 0; i--)); do
        if (((1 << i) & num)); then
            words+=("${rev[i]}")
        fi
    done
    candidate="${override_dir}/$(
        IFS=-
        echo "${words[*]}"
    ).yaml"
    if [ -f "${candidate}" ]; then
        echo "File found: ${candidate}" >&2
        args+=("--values" "${candidate}")
    else
        echo "File not found: ${candidate}" >&2
    fi
done

echo "Resulting override args: ${args[*]}" >&2
echo "${args[*]}"
