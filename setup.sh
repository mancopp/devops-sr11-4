#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# Obraz zawiera tylko to, co potrzebne każdej maszynie, zanim Ansible zacznie działać.
# Wszystko zależne od roli maszyny (PostgreSQL, Java, nginx, aplikacja) instaluje Ansible.
sudo -E apt-get update -y
sudo -E apt-get upgrade -y

# ansible: provisioner ansible_local uruchamia go wewnątrz maszyny (pakiet Ubuntu zawiera kolekcje community.*)
# acl: wymagany przez Ansible do become_user na nieuprzywilejowanego użytkownika (postgres, eticket)
sudo -E apt-get install -y ansible acl

# Czyszczenie cache, aby zmniejszyć rozmiar ostatecznego obrazu
sudo apt-get clean
