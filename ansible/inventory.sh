#!/bin/bash

terraform -chdir=$(dirname "$0")/../terraform/env/dev output -raw ansible_inventory
