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
```

First run takes ~15 min (Maven and npm build the app inside the VMs). Then open http://\<subnet\>.12 (see [Private network subnet](#private-network-subnet); the host-only network is reachable from the host). Seeded accounts: `passenger@example.com` / `Passenger123!`, `inspector@example.com` / `Inspector123!`.

```bash
vagrant provision backend   # re-run Ansible on one machine (rebuilds only if the app repo changed)
vagrant destroy -f
```

## Architecture

### Private network subnet

VMs get `<subnet>.10/.11/.12` on VMware's existing host-only network (vmnet1). Its subnet differs per installation, so the Vagrantfile reads it from the host (macOS/Linux: VMware `networking` file, Windows: `ipconfig`). Check the assigned IPs with `vagrant ssh db -c "ip -br a"`. If vmnet1 is not found it falls back to `192.168.62`. To force a subnet, set `VM_SUBNET` (e.g. `VM_SUBNET=192.168.171`) for every `vagrant` command.

### VMs

| VM | IP | Runs | Firewall (ufw, default deny) |
|---|---|---|---|
| `db` | `<subnet>.10` | PostgreSQL 16 | 22, 5432 from backend only |
| `backend` | `<subnet>.11` | Spring Boot jar (Java 21) as systemd service | 22, 8080 from frontend only |
| `frontend` | `<subnet>.12` | nginx: Angular build + `/api/` proxy to backend | 22, 80 |

The app ([piisw-projekt](https://github.com/mancopp/piisw-projekt)) is cloned and built on the VMs by Ansible. All machines get `PermitRootLogin no` and `PasswordAuthentication no`.

Ansible runs inside each guest (`ansible_local` provisioner), so the host only needs Vagrant. Layout:

```text
ansible/
├── site.yml, inventory.ini
├── group_vars/all.yml      # app repo, DB credentials, JWT secret (IPs come from the Vagrantfile)
├── host_vars/<vm>.yml      # per-VM firewall rules
└── roles/common | postgres | backend | frontend
```

## Troubleshooting

- `Error halting Vagrant machine` / `utility service key file`: Vagrant VMware Utility is missing or not running.
- Browser can't reach `<subnet>.12` (`No route to host`; on macOS check System Settings → Privacy & Security → Local Network for your browser/terminal): tunnel instead with `vagrant ssh frontend -- -N -L 18080:localhost:80` and open http://localhost:18080.
- `/bin/bash^M: bad interpreter` or the backend can't log in to the database: files were checked out with CRLF line endings. Re-clone the repo (`.gitattributes` forces LF).
- Windows with Hyper-V/WSL2 enabled: VMware Workstation 17 still works (it runs on top of Hyper-V), just slower. The Vagrantfile forces the `vmware_desktop` provider.
