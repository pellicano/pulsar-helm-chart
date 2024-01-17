#!/usr/bin/env bash

# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

# Copyright The Helm Authors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -o errexit
set -o nounset
set -o pipefail

DEFAULT_CHART_TESTING_VERSION=v3.10.1
DEFAULT_YAMLLINT_VERSION=1.33.0
DEFAULT_YAMALE_VERSION=4.0.4

show_help() {
cat << EOF
Usage: $(basename "$0") <options>
    -h, --help          Display help
    -v, --version       The chart-testing version to use (default: $DEFAULT_CHART_TESTING_VERSION)"
EOF
}

main() {
    local version="$DEFAULT_CHART_TESTING_VERSION"
    local yamllint_version="$DEFAULT_YAMLLINT_VERSION"
    local yamale_version="$DEFAULT_YAMALE_VERSION"

    parse_command_line "$@"

    install_chart_testing
}

parse_command_line() {
    while :; do
        case "${1:-}" in
            -h|--help)
                show_help
                exit
                ;;
            -v|--version)
                if [[ -n "${2:-}" ]]; then
                    version="$2"
                    shift
                else
                    echo "ERROR: '-v|--version' cannot be empty." >&2
                    show_help
                    exit 1
                fi
                ;;
            --yamllint-version)
                if [[ -n "${2:-}" ]]; then
                    yamllint_version="$2"
                    shift
                else
                    echo "ERROR: '--yamllint-version' cannot be empty." >&2
                    show_help
                    exit 1
                fi
                ;;
            --yamale-version)
                if [[ -n "${2:-}" ]]; then
                    yamale_version="$2"
                    shift
                else
                    echo "ERROR: '--yamale-version' cannot be empty." >&2
                    show_help
                    exit 1
                fi
                ;;
            *)
                break
                ;;
        esac

        shift
    done
}

install_chart_testing() {
    if [[ ! -d "$RUNNER_TOOL_CACHE" ]]; then
        echo "Cache directory '$RUNNER_TOOL_CACHE' does not exist" >&2
        exit 1
    fi

    local arch
    arch=$(uname -m)
    local cache_dir="$RUNNER_TOOL_CACHE/ct/$version/$arch"
    local venv_dir="$cache_dir/venv"

    if [[ ! -d "$cache_dir" ]]; then
        mkdir -p "$cache_dir"

        echo "Installing chart-testing..."
        curl -sSLo ct.tar.gz "https://github.com/helm/chart-testing/releases/download/$version/chart-testing_${version#v}_linux_amd64.tar.gz"
        tar -xzf ct.tar.gz -C "$cache_dir"
        rm -f ct.tar.gz

        echo 'Creating virtual Python environment...'
        python3 -m venv "$venv_dir"

        echo 'Activating virtual environment...'
        # shellcheck disable=SC1090
        source "$venv_dir/bin/activate"

        echo 'Installing yamllint...'
        pip3 install "yamllint==${yamllint_version}"

        echo 'Installing Yamale...'
        pip3 install "yamale==${yamale_version}"
    fi

    # https://github.com/helm/chart-testing-action/issues/62
    echo 'Adding ct directory to PATH...'
    echo "$cache_dir" >> "$GITHUB_PATH"

    echo 'Setting CT_CONFIG_DIR...'
    echo "CT_CONFIG_DIR=$cache_dir/etc" >> "$GITHUB_ENV"

    echo 'Configuring environment variables for virtual environment for subsequent workflow steps...'
    echo "VIRTUAL_ENV=$venv_dir" >> "$GITHUB_ENV"
    echo "$venv_dir/bin" >> "$GITHUB_PATH"

    "$cache_dir/ct" version
}

main "$@"