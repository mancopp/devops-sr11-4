# Keeps Vagrant from picking Hyper-V on Windows hosts where it is enabled.
ENV["VAGRANT_DEFAULT_PROVIDER"] ||= "vmware_desktop"

# VMware reuses an existing host-only vmnet whose subnet matches; creating a new one fails on some
# Fusion/Workstation setups, so point this at your vmnet1 subnet if `vagrant up` reports a vmnet error.
# The default avoids 192.168.56, which VirtualBox's host-only adapter usually holds.
SUBNET = ENV.fetch("VM_SUBNET", "192.168.62")

MACHINES = {
  "db"       => { ip: "#{SUBNET}.10", memory: 1024, cpus: 1 },
  "backend"  => { ip: "#{SUBNET}.11", memory: 2048, cpus: 2 },
  "frontend" => { ip: "#{SUBNET}.12", memory: 2048, cpus: 2 },
}

Vagrant.configure("2") do |config|
  config.vm.box = "moje-ubuntu-java"

  # Order matters: vagrant up provisions machines one by one, so db is ready before the backend starts.
  MACHINES.each do |name, spec|
    config.vm.define name do |node|
      node.vm.hostname = name
      node.vm.network "private_network", ip: spec[:ip]

      node.vm.provider "vmware_desktop" do |v|
        v.gui = false
        v.memory = spec[:memory]
        v.cpus = spec[:cpus]
      end

      # ansible_local runs Ansible inside each guest, so the host needs no Ansible (works on Windows too).
      node.vm.provision "shell", inline: "command -v ansible-playbook >/dev/null || (apt-get update -y && apt-get install -y ansible)"
      node.vm.provision "ansible_local" do |ansible|
        ansible.install = false
        ansible.compatibility_mode = "2.0"
        ansible.provisioning_path = "/vagrant/ansible"
        ansible.playbook = "site.yml"
        ansible.inventory_path = "inventory.ini"
        ansible.limit = name
        ansible.extra_vars = MACHINES.to_h { |n, m| ["#{n}_ip", m[:ip]] }
      end
    end
  end
end
