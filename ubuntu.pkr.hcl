packer {
  required_plugins {
    vagrant = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/vagrant"
    }
  }
}

source "vagrant" "baza_ubuntu" {
  source_path  = "bento/ubuntu-24.04"
  provider     = "vmware_desktop"
  add_force    = true
  communicator = "ssh"
  output_dir   = "output-baza_ubuntu"
}

build {
  sources = ["source.vagrant.baza_ubuntu"]

  provisioner "shell" {
    script = "./setup.sh"
  }

  # The vagrant builder packages the box into output-baza_ubuntu/package.box itself.
  # The command works in both sh (macOS/Linux) and cmd (Windows).
  post-processor "shell-local" {
    inline = ["vagrant box add --force --name moje-ubuntu-ansible output-baza_ubuntu/package.box"]
  }
}
