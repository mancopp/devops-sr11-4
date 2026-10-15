# devops-sr11-4

Packer builds a Vagrant box (`moje-ubuntu-java`: Ubuntu 24.04 + OpenJDK 17 + Python 3) on VMware. Works on Apple Silicon (arm64) and Windows/Linux (amd64).

## 1. Install (once)

**macOS (Apple Silicon)**

1. [VMware Fusion Pro](https://support.broadcom.com/group/ecx/productdownloads?subfamily=VMware%20Fusion) (free, needs a Broadcom account)
2. ```bash
   brew install hashicorp/tap/hashicorp-vagrant hashicorp/tap/packer
   brew install --cask vagrant-vmware-utility
   vagrant plugin install vagrant-vmware-desktop
   ```

**Windows (x64)**

1. [VMware Workstation Pro](https://support.broadcom.com/group/ecx/productdownloads?subfamily=VMware%20Workstation%20Pro) (free, needs a Broadcom account)
2. [Vagrant VMware Utility](https://developer.hashicorp.com/vagrant/install/vmware) (MSI)
3. In PowerShell, then open a new terminal:
   ```powershell
   winget install Hashicorp.Vagrant Hashicorp.Packer
   vagrant plugin install vagrant-vmware-desktop
   ```

## 2. Build the box

```bash
packer init .
packer build -force ubuntu.pkr.hcl
```

Takes ~5 min. Output: `output-baza_ubuntu/package.box`, registered in Vagrant as `moje-ubuntu-java`.

## 3. Run

```bash
vagrant up
vagrant ssh -c "java -version"
vagrant destroy -f
```

## Troubleshooting

- `Error halting Vagrant machine` / `utility service key file`: Vagrant VMware Utility is missing or not running.
- `/bin/bash^M: bad interpreter`: `setup.sh` has CRLF line endings. Re-clone the repo (`.gitattributes` forces LF).
