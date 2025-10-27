# -*- coding: utf-8 -*-

from __future__ import (absolute_import, division, print_function)
__metaclass__ = type

DOCUMENTATION = """
    name: sakura_secret
    short_description: lookup secrets from Sakura Cloud Secret Manager
    description:
        - This lookup returns secrets from Sakura Cloud Secret Manager using usacloud CLI
        - Requires usacloud CLI to be installed and configured with proper credentials
    options:
      _terms:
        description: The name(s) of the secret(s) to retrieve
        required: True
        type: list
        elements: str
      zone:
        description: Sakura Cloud zone where the vault is located
        default: tk1a
        type: str
      vault_id:
        description: Secret Manager vault ID
        required: True
        type: str
    notes:
      - This lookup requires usacloud CLI to be installed and configured
      - The usacloud CLI must be authenticated with proper permissions to access the Secret Manager
    seealso:
      - name: Sakura Cloud Documentation
        description: Official Sakura Cloud documentation
        link: https://manual.sakura.ad.jp/cloud/
"""

EXAMPLES = """
- name: Get a single secret from Sakura Cloud Secret Manager
  debug:
    msg: "{{ lookup('sakura_secret', 'secret-name', vault_id='123456789012', zone='tk1a') }}"

- name: Use secret in playbook with default zone (tk1a)
  set_fact:
    metrics_endpoint: "{{ lookup('sakura_secret', 'secret-name', vault_id='123456789012') }}"

- name: Get multiple secrets at once
  set_fact:
    secrets: "{{ lookup('sakura_secret', 'secret1', 'secret2', vault_id='123456789012') }}"

- name: Use in environment variables
  command: /usr/bin/some-command
  environment:
    SOME_SECRET: "{{ lookup('sakura_secret', 'secret-name', vault_id='123456789012') }}"
"""

RETURN = """
  _raw:
    description:
      - The secret value(s) retrieved from Sakura Cloud Secret Manager
    type: list
    elements: str
"""

from ansible.errors import AnsibleError
from ansible.plugins.lookup import LookupBase
from ansible.module_utils._text import to_native

import json
import subprocess

class LookupModule(LookupBase):
    def run(self, terms, variables=None, **kwargs):
        """
        Execute the lookup and return secret values from Sakura Cloud Secret Manager

        :param terms: List of secret names to retrieve
        :param variables: Ansible variables (not directly used)
        :param kwargs: Additional options (zone, vault_id)
        :return: List of secret values
        """
        self.set_options(var_options=variables, direct=kwargs)

        zone = self.get_option('zone')
        if not zone:
            zone = 'tk1a'

        vault_id = self.get_option('vault_id')

        if not vault_id:
            raise AnsibleError('vault_id parameter is required for sakura_secret lookup')

        if not terms:
            raise AnsibleError('At least one secret name is required for sakura_secret lookup')

        ret = []
        for term in terms:
            secret_name = term

            # Build usacloud command
            cmd = [
                'usacloud', 'rest', 'request',
                '--zone', zone,
                f'/secretmanager/vaults/{vault_id}/secrets/unveil',
                '-XPOST',
                '-d', json.dumps({"Secret": {"Name": secret_name}})
            ]

            self._display.vvv(f"Running command: {' '.join(cmd)}")

            try:
                result = subprocess.run(
                    cmd,
                    capture_output=True,
                    text=True,
                    check=True
                )
                response = json.loads(result.stdout)

                # Check for errors in the response
                if not ('is_ok' in response):
                    raise AnsibleError('Unexpected response structure')

                if not response['is_ok']:
                    error_msg = response.get('error_msg', 'Unknown error')
                    errors = response.get('Errors', {})
                    if errors:
                        # Errors is a dict, convert it to a readable string
                        error_details = json.dumps(errors)
                        raise AnsibleError(
                            f"Failed to retrieve secret '{secret_name}' from vault '{vault_id}' in zone '{zone}': {error_msg} - {error_details}"
                        )
                    else:
                        raise AnsibleError(
                            f"Failed to retrieve secret '{secret_name}' from vault '{vault_id}' in zone '{zone}': {error_msg}"
                        )

                secret_value = response['Secret']['Value']
                ret.append(secret_value)

            except subprocess.CalledProcessError as e:
                error_msg = e.stderr if e.stderr else str(e)
                raise AnsibleError(
                    f"Failed to retrieve secret '{secret_name}' from vault '{vault_id}' in zone '{zone}': {error_msg}"
                )
            except json.JSONDecodeError as e:
                raise AnsibleError(
                    f"Failed to parse JSON response from usacloud for secret '{secret_name}': {to_native(e)}"
                )
            except FileNotFoundError:
                raise AnsibleError(
                    "usacloud command not found. Please ensure usacloud CLI is installed and available in PATH."
                )
            except Exception as e:
                raise AnsibleError(
                    f"Unexpected error retrieving secret '{secret_name}': {to_native(e)}"
                )

        return ret
