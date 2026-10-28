#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# The box holds only what every VM needs before Ansible can run.
# Everything role-specific (PostgreSQL, Java, nginx, the app) is installed by Ansible.
sudo -E apt-get update -y
sudo -E apt-get upgrade -y

# ansible: the ansible_local provisioner runs it inside the guest (Ubuntu's package bundles the community.* collections)
# acl: Ansible needs it for become_user to an unprivileged user (postgres, eticket)
sudo -E apt-get install -y ansible acl

sudo apt-get clean
