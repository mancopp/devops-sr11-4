# Keeps Vagrant from picking Hyper-V on Windows hosts where it is enabled.
ENV["VAGRANT_DEFAULT_PROVIDER"] ||= "vmware_desktop"

# VMware reuses an existing host-only vmnet whose subnet matches, while creating a new one fails on some
# Fusion/Workstation setups. vmnet1's subnet is random per installation, so read it from the host.
def vmnet1_subnet
  if Vagrant::Util::Platform.windows?
    # Locale-independent: take the first IPv4 address in the ipconfig section of the VMnet1 adapter.
    section = `ipconfig`.b.split(/\r?\n(?=\S)/).find { |s| s.include?("VMnet1") }
    section && section[/\b(\d+\.\d+\.\d+)\.\d+\b/, 1]
  else
    conf = ["/Library/Preferences/VMware Fusion/networking", "/etc/vmware/networking"].find { |f| File.readable?(f) }
    conf && File.read(conf)[/VNET_1_HOSTONLY_SUBNET (\d+\.\d+\.\d+)\.0/, 1]
  end
rescue StandardError
  nil
end

# The fallback avoids 192.168.56, which VirtualBox's host-only adapter usually holds.
SUBNET = ENV.fetch("VM_SUBNET") { vmnet1_subnet || "192.168.62" }

MACHINES = {
  "db"       => { ip: "#{SUBNET}.10", memory: 1024, cpus: 1 },
  "backend"  => { ip: "#{SUBNET}.11", memory: 2048, cpus: 2 },
  "frontend" => { ip: "#{SUBNET}.12", memory: 2048, cpus: 2 },
}

Vagrant.configure("2") do |config|
  config.vm.box = "moje-ubuntu-ansible"

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

      # ansible_local runs Ansible inside each guest (baked into the box), so the host needs no Ansible.
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
