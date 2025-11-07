#!/bin/bash

ENV=${ENV:-dev}
terraform -chdir=$(dirname "$0")/../terraform/env/${ENV} output -raw ansible_inventory
