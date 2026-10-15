Vagrant.configure("2") do |config|
  config.vm.box = "moje-ubuntu-java"
  config.vm.hostname = "ubuntu-java"

  config.vm.provider "vmware_desktop" do |v|
    v.gui = false
    v.memory = 2048
    v.cpus = 2
  end
end
