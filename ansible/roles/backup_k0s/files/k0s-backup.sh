#!/bin/bash

set -eux -o pipefail

# ICTSC2025 RSA PubKey
recipient="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDh+ia6/sQpRKoEzvZYT1UuDUKBL8NCLeZAkQ9S4IrNSzqlZmhrbEUp7rmNXk7IG+8I6o6ofS8I1hdEuEjxCnSuU0VbpaJNA9jW3aOfBcPndLl6feHKe3tE8I0zB0FQKWT5tlnxAel2zzyQmxXTh++eICrZPrDOx9DszLn9J+TYTI5zHVSvjEbaXSTDLoKjeakTLw0bK1toqlWSVCAIG3LOfGk/Hz4H8ebi70C+BxA0mt0JPPqW9s9SmnBX7aHAO1SQcte1LGHOd90qwDzNGOmmudSkoRG1RTzLREJ7F6QfAEhjOs7zkf9ytl3ncxfBpUaknBe4iwYVcxmyhPxS0leP"

tmp_out="${RUNTIME_DIRECTORY:-/tmp}/k0s_backup.tar.gz.age"
dest="s3://${BUCKET:-"ictsc-k8s-backup"}/${ENV:-dev}/k0s/k0s_backup_$(date --utc "+%Y-%m-%dT%H_%M_%SZ").tar.gz.age"

k0s backup --save-path - | age --encrypt --recipient "$recipient" --output "$tmp_out"
s4cmd put --endpoint-url=https://s3.isk01.sakurastorage.jp "$tmp_out" "$dest"
