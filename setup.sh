#!/bin/bash
# Aktualizacja repozytoriów
sudo apt-get update -y

# Instalacja niezbędnych pakietów (Python dla Ansible, Java dla Backendu)
sudo apt-get install -y python3 python3-pip openjdk-17-jre

# Czyszczenie cache, aby zmniejszyć rozmiar ostatecznego obrazu
sudo apt-get clean
