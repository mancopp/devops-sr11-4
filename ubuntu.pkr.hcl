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

  # Wywołanie skryptu z Kroku 1 wewnątrz budowanej maszyny
  provisioner "shell" {
    script = "./setup.sh"
  }

  # Builder vagrant sam pakuje maszynę do output-baza_ubuntu/package.box.
  # Komenda działa zarówno w sh (macOS), jak i w cmd (Windows).
  post-processor "shell-local" {
    inline = ["vagrant box add --force --name moje-ubuntu-java output-baza_ubuntu/package.box"]
  }
}
