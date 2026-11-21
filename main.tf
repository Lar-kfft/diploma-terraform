terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
}

provider "yandex" {
  cloud_id  = "b1gmrl0s8ovg8e9idolg"
  folder_id = "b1gm3kk8lsfs8nbujfel"
  zone      = "ru-central1-a"
}

resource "yandex_vpc_network" "main" {
  name = "diploma-network"
}

resource "yandex_vpc_subnet" "subnet_a" {
  name           = "subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.main.id
  v4_cidr_blocks = ["192.168.10.0/24"]
}

resource "yandex_vpc_subnet" "subnet_b" {
  name           = "subnet-b"
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.main.id
  v4_cidr_blocks = ["192.168.11.0/24"]
}

resource "yandex_vpc_subnet" "subnet_d" {
  name           = "subnet-d"
  zone           = "ru-central1-d"
  network_id     = yandex_vpc_network.main.id
  v4_cidr_blocks = ["192.168.12.0/24"]
}

output "network_id" {
  value = yandex_vpc_network.main.id
}

output "subnet_ids" {
  value = {
    a = yandex_vpc_subnet.subnet_a.id
    b = yandex_vpc_subnet.subnet_b.id
    d = yandex_vpc_subnet.subnet_d.id
  }
}

resource "yandex_iam_service_account" "k8s_cluster_sa" {
  name = "k8s-cluster-sa"
}

resource "yandex_resourcemanager_folder_iam_member" "k8s_cluster_sa_editor" {
  folder_id = "b1gm3kk8lsfs8nbujfel"
  role      = "editor"
  member    = "serviceAccount:${yandex_iam_service_account.k8s_cluster_sa.id}"
}

resource "yandex_iam_service_account" "k8s_node_sa" {
  name = "k8s-node-sa"
}

resource "yandex_resourcemanager_folder_iam_member" "k8s_node_sa_editor" {
  folder_id = "b1gm3kk8lsfs8nbujfel"
  role      = "editor"
  member    = "serviceAccount:${yandex_iam_service_account.k8s_node_sa.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "k8s_node_sa_vpc" {
  folder_id = "b1gm3kk8lsfs8nbujfel"
  role      = "vpc.publicAdmin"
  member    = "serviceAccount:${yandex_iam_service_account.k8s_node_sa.id}"
}

resource "yandex_compute_instance" "k3s_vm" {
  name        = "k3s-node-yc"
  platform_id = "standard-v3"
  zone        = "ru-central1-d"

  resources {
    cores  = 2
    memory = 4
  }

  boot_disk {
    initialize_params {
      image_id = "fd8bhk915ujan6c83qui"
      size     = 20
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet_d.id
    nat       = true
  }

  metadata = {
    user-data = file("${path.module}/k3s-cloud-init.yaml")
    ssh-keys  = "ubuntu:${var.ssh_public_key}"
  }

  scheduling_policy {
    preemptible = false
  }
}

output "k3s_vm_public_ip" {
  value = yandex_compute_instance.k3s_vm.network_interface[0].nat_ip_address
}

variable "ssh_public_key" {
  description = "Public SSH key for ubuntu user"
  type        = string
  default     = ""
}
