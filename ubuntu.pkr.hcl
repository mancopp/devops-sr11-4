packer {
  required_plugins {
    vagrant = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/vagrant"
    }
  }
}

source "vagrant" "baza_ubuntu" {
  # Używamy oficjalnego obrazu Ubuntu 24.04 jako punktu startowego
  source_path = "bento/ubuntu-24.04"
  provider    = "vmware_desktop"
  # Packer wyeksportuje gotową maszynę jako nowy "box" dla Vagranta
  add_force   = true
}

build {
  sources = ["source.vagrant.baza_ubuntu"]

  # Wywołanie skryptu z Kroku 1 wewnątrz budowanej maszyny
  provisioner "shell" {
    script = "./setup.sh"
  }

  # Zapisanie wyniku do pliku z rozszerzeniem .box
  post-processor "vagrant" {
    output = "moje-ubuntu-java.box"
    keep_input_artifact = false
  }
}
