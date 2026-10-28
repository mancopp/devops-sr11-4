# devops-sr11-4

Three VMware VMs (PostgreSQL, Spring Boot backend, Angular frontend) built from a Packer box, created by Vagrant and configured by Ansible. Works on Apple Silicon (arm64) and Windows/Linux (amd64).

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

Takes ~5 min. Output: `output-baza_ubuntu/package.box`, registered in Vagrant as `moje-ubuntu-ansible`. Rebuild only after changing `ubuntu.pkr.hcl` or `setup.sh`, then recreate the VMs (`vagrant destroy -f && vagrant up`): existing VMs keep the box they were created from.

## 3. Run

Put the vault password (ask a teammate) into `.vault_pass` next to the Vagrantfile; it is gitignored. See [Secrets](#secrets).

```bash
vagrant up
```

First run takes ~15 min (Maven and npm build the app inside the VMs). Then open http://\<subnet\>.12 (see [Private network subnet](#private-network-subnet); the host-only network is reachable from the host). Seeded accounts: `passenger@example.com` / `Passenger123!`, `inspector@example.com` / `Inspector123!`.

```bash
vagrant provision backend   # re-run Ansible on one machine (rebuilds only if the app repo changed)
vagrant destroy -f
```

## Architecture

### Technology choices

| Layer | Choice | Why |
|---|---|---|
| Hypervisor | VMware Fusion Pro (macOS) / Workstation Pro (Windows, Linux) | The team works on both Apple Silicon Macs and x64 PCs. VirtualBox only recently gained Apple Silicon support and has few arm64 Vagrant boxes; VMware runs on both architectures, is free since 2024, has an official Vagrant provider and `bento` boxes for arm64 and amd64. The assignment allows a hypervisor better suited to the hardware. |
| Guest OS | Ubuntu Server 24.04 LTS (`bento/ubuntu-24.04`) | Supported until 2029. Its own repositories carry everything we need in the right versions (PostgreSQL 16, OpenJDK 21, nginx, Ansible), Python 3 for Ansible is preinstalled, `ufw` ships with it. Same OS on all VMs, so one Packer box serves all three. |
| Database | PostgreSQL 16 | The database the app is written for. Default PostgreSQL version in Ubuntu 24.04, so no extra apt repository. Ansible has dedicated modules for users, databases and `pg_hba` (`community.postgresql`). |
| Application server | Spring Boot's embedded Tomcat, Java 21, run by systemd | Spring Boot packages the server into the jar, so a standalone Tomcat/WildFly would add nothing. Java 21 is the LTS release the app targets. systemd restarts the process on failure and starts it on boot. |
| Web server | nginx | Serves the static Angular build and reverse-proxies `/api/` to the backend. Browser and API share one origin (no CORS setup), and only port 80 on the frontend is exposed to the host; the backend accepts connections from the frontend VM only. |
| Image | Packer (`vagrant` builder) | Rebuilds the base box from code. The `vagrant` builder starts from an existing `bento` box instead of an ISO install, which keeps the build at ~5 min and works on both architectures. |
| Provisioning | Ansible via `ansible_local` | Runs inside each guest, so the host needs only Vagrant and the setup works the same on macOS and Windows (Ansible doesn't run natively on Windows). |

The app is built on the VMs from its git repository. This keeps the host free of Java and Node.js at the cost of a slower first `vagrant up` and build tools on the target machines; in production the jar and static files would come from CI as artifacts.

### What goes into the Packer box vs. Ansible

| Packer box ([setup.sh](setup.sh)) | Ansible ([ansible/](ansible/site.yml)) |
|---|---|
| Ubuntu 24.04 (bento) with updates applied | Firewall rules, SSH hardening (`common`) |
| `ansible` (with `community.*` collections), `acl` | PostgreSQL, database and user (`postgres`) |
| Python 3 (part of Ubuntu) | Java 21, Maven, backend build and service (`backend`) |
| | Node.js 22, nginx, frontend build (`frontend`) |

The rule: the box holds only what **every** VM needs **before** Ansible can run. Everything else is in Ansible.

- **Ansible itself goes into the box.** `ansible_local` runs it inside each VM, so without it every new VM would first have to download and install it, depending on the package mirror just to start configuring itself. `acl` is in the same category: Ansible needs it to switch to the `postgres` and `eticket` users.
- **Role-specific software stays out of the box.** All three VMs share one box. Baking in Java, PostgreSQL or nginx would put each of them on two machines that never use it, enlarge the attack surface and the image, and force a rebuild plus VM recreation for every version bump. The first version of the box shipped OpenJDK 17, which the backend (Java 21) could not even use.
- **Configuration stays in Ansible, even when it is shared.** SSH hardening and firewall defaults apply to every VM and rarely change, so they could live in the box. Keeping them in the `common` role means one place defines them, they depend on per-VM data (IPs, open ports), and `vagrant provision` re-applies them if someone changes a VM by hand. The box only guarantees that Ansible can run.
- **Updates go into the box.** `apt-get upgrade` at build time means new VMs start patched; Ansible does not upgrade packages on every run, which keeps provisioning predictable.

### Private network subnet

VMs get `<subnet>.10/.11/.12` on VMware's existing host-only network (vmnet1). Its subnet differs per installation, so the Vagrantfile reads it from the host (macOS/Linux: VMware `networking` file, Windows: `ipconfig`). Check the assigned IPs with `vagrant ssh db -c "ip -br a"`. If vmnet1 is not found it falls back to `192.168.62`. To force a subnet, set `VM_SUBNET` (e.g. `VM_SUBNET=192.168.171`) for every `vagrant` command.

### VMs

| VM | IP | Runs | Firewall (ufw, default deny) |
|---|---|---|---|
| `db` | `<subnet>.10` | PostgreSQL 16 | 22 from host, 5432 from backend only |
| `backend` | `<subnet>.11` | Spring Boot jar (Java 21) as systemd service | 22 from host, 8080 from frontend only |
| `frontend` | `<subnet>.12` | nginx: Angular build + `/api/` proxy to backend | 22 from host, 80 |

The app ([piisw-projekt](https://github.com/mancopp/piisw-projekt)) is cloned and built on the VMs by Ansible. All machines get `PermitRootLogin no` and `PasswordAuthentication no`. "From host" means the host's own address (`.1`) on the host-only network and on the VM's NAT network (Vagrant connects over NAT), so the VMs don't accept SSH from each other.

### Secrets

The database password and JWT secret are in [ansible/group_vars/all/vault.yml](ansible/group_vars/all/vault.yml), encrypted with ansible-vault; [main.yml](ansible/group_vars/all/main.yml) refers to them as `vault_*` variables. The vault password lives only in `.vault_pass` on each teammate's host (gitignored) and is shared outside the repo. Vagrant copies it into each guest (`/home/vagrant/.vault_pass`, mode 0400) before running Ansible; without it provisioning stops with an error.

To view or change the secrets without Ansible on the host:

```bash
vagrant ssh db -c "cd /vagrant/ansible && ansible-vault edit --vault-password-file ~/.vault_pass group_vars/all/vault.yml"
```

Then `vagrant provision` the affected VMs. Changing `vault_db_password` after the database user exists updates its password on the next `db` provision; provision `backend` afterwards.

Ansible runs inside each guest (`ansible_local` provisioner), so the host only needs Vagrant. Layout:

```text
ansible/
├── site.yml, inventory.ini
├── group_vars/all/main.yml # app repo, DB name/user, ports (IPs come from the Vagrantfile)
├── group_vars/all/vault.yml # encrypted: DB password, JWT secret
├── host_vars/<vm>.yml      # per-VM firewall rules
└── roles/common | postgres | backend | frontend
```

## Manual setup (proof of concept)

The same system built by hand, without Packer, Vagrant or Ansible. This is the procedure the automation replaces; each step names its automated counterpart. `<subnet>` is the host-only subnet, `<password>` the database password.

### 1. VMs and network (→ Packer + Vagrant)

1. In VMware create three VMs (`db` 1 vCPU/1 GB, `backend` and `frontend` 2 vCPU/2 GB) from the Ubuntu Server 24.04 ISO, each with two network adapters: NAT (internet access) and host-only (vmnet1).
2. In the installer pick OpenSSH server, create an admin user, then update: `sudo apt update && sudo apt full-upgrade -y`.
3. Give the host-only adapter a static address (`.10`, `.11`, `.12`) in `/etc/netplan/60-private.yaml`, then `sudo netplan apply`:

   ```yaml
   network:
     version: 2
     ethernets:
       ens192:                # host-only adapter, check with `ip -br a`
         addresses: [<subnet>.10/24]
   ```

4. Check that the VMs ping each other and the host reaches them: `ping <subnet>.11`.

### 2. Baseline on every VM (→ `common` role)

1. Copy an SSH key from the host before disabling passwords: `ssh-copy-id user@<subnet>.10`.
2. Harden SSH, validate, restart:

   ```bash
   printf 'PermitRootLogin no\nPasswordAuthentication no\n' | sudo tee /etc/ssh/sshd_config.d/01-hardening.conf
   sudo sshd -t && sudo systemctl restart ssh
   ```

3. Firewall:

   ```bash
   sudo ufw default deny incoming
   sudo ufw allow from <subnet>.1 to any port 22 proto tcp   # the host only
   sudo ufw enable
   ```

4. From another terminal, check that SSH with the key still works and `ssh root@…` is refused before closing the session.

### 3. Database on `db` (→ `postgres` role)

```bash
sudo apt install -y postgresql-16
sudo -u postgres psql -c "CREATE USER eticket WITH PASSWORD '<password>';"
sudo -u postgres createdb -O eticket eticket
sudo sed -i "s/^#listen_addresses.*/listen_addresses = 'localhost,<subnet>.10'/" /etc/postgresql/16/main/postgresql.conf
echo "host eticket eticket <subnet>.11/32 scram-sha-256" | sudo tee -a /etc/postgresql/16/main/pg_hba.conf
sudo systemctl restart postgresql
sudo ufw allow from <subnet>.11 to any port 5432 proto tcp
```

Check from `backend`: `psql -h <subnet>.10 -U eticket eticket` (needs `postgresql-client`) connects, and the same command from `frontend` times out.

### 4. Backend on `backend` (→ `backend` role)

1. Install the toolchain and a service user:

   ```bash
   sudo apt install -y openjdk-21-jdk-headless maven git
   sudo useradd --system --home /opt/eticket --create-home --shell /usr/sbin/nologin eticket
   ```

2. Build and install the jar:

   ```bash
   sudo -u eticket git clone --depth 1 https://github.com/mancopp/piisw-projekt.git /opt/eticket/src
   cd /opt/eticket/src/backend && sudo -u eticket mvn -B -DskipTests package
   sudo cp target/eticket-backend-*.jar /opt/eticket/app.jar
   ```

3. Write `/etc/eticket/backend.env` (owner `root:eticket`, mode 0640) with `SERVER_PORT`, `DB_URL=jdbc:postgresql://<subnet>.10:5432/eticket`, `DB_USER`, `DB_PASSWORD`, `JWT_SECRET` (`openssl rand -hex 64`) and `CORS_ALLOWED_ORIGINS=http://<subnet>.12`.
4. Create `/etc/systemd/system/eticket-backend.service` running `/usr/bin/java -jar /opt/eticket/app.jar` as `eticket` with `EnvironmentFile=/etc/eticket/backend.env` and `Restart=on-failure`, then `sudo systemctl daemon-reload && sudo systemctl enable --now eticket-backend`.
5. Open the port to the frontend only: `sudo ufw allow from <subnet>.12 to any port 8080 proto tcp`.

Check with `journalctl -u eticket-backend -f` that the app connected to the database and started, then `curl http://<subnet>.11:8080/` from `frontend` gets an HTTP response.

### 5. Frontend on `frontend` (→ `frontend` role)

1. Install Node.js 22 from NodeSource (Ubuntu's Node 18 is too old for Angular) and nginx:

   ```bash
   curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo tee /etc/apt/keyrings/nodesource.asc
   echo "deb [signed-by=/etc/apt/keyrings/nodesource.asc] https://deb.nodesource.com/node_22.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list
   sudo apt update && sudo apt install -y nodejs nginx git
   ```

2. Clone the app, set `API_BASE_URL = '/api/v1'` in `frontend/src/app/core/config/api.config.ts`, build and copy:

   ```bash
   cd frontend && npm ci && npm run build
   sudo cp -r dist/webapp/browser/. /var/www/eticket/
   ```

3. Add the nginx site from [eticket.conf.j2](ansible/roles/frontend/templates/eticket.conf.j2) as `/etc/nginx/sites-available/eticket`, link it into `sites-enabled`, remove `sites-enabled/default`, then `sudo nginx -t && sudo systemctl reload nginx`.
4. `sudo ufw allow 80/tcp`.

Open `http://<subnet>.12` on the host and log in with a seeded account.

### What the manual run shows

Each VM takes dozens of commands and several hand-edited files, and nothing records what was done. Rebuilding a VM, adding a fourth one, or changing an IP means repeating everything without mistakes. The automation turns each step into code: Packer replaces the OS install and updates, Vagrant the VM creation and network setup, Ansible steps 2–5 (and re-applies them idempotently on `vagrant provision`).

## Troubleshooting

- `Error halting Vagrant machine` / `utility service key file`: Vagrant VMware Utility is missing or not running.
- Browser can't reach `<subnet>.12` (`No route to host`; on macOS check System Settings → Privacy & Security → Local Network for your browser/terminal): tunnel instead with `vagrant ssh frontend -- -N -L 18080:localhost:80` and open http://localhost:18080.
- `/bin/bash^M: bad interpreter` or the backend can't log in to the database: files were checked out with CRLF line endings. Re-clone the repo (`.gitattributes` forces LF).
- Windows with Hyper-V/WSL2 enabled: VMware Workstation 17 still works (it runs on top of Hyper-V), just slower. The Vagrantfile forces the `vmware_desktop` provider.
