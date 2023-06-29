terraform {
  required_providers {
    tencentcloud = {
      source = "tencentcloudstack/tencentcloud"
      version = "1.81.9"
    }
  }
}

variable "k8s_version" {
  default = "1.26.1"
}
variable "worker_cpu_cores" {
  default = 4
}
variable "worker_memory_GB" {
  default = 16
}


locals {
  az_name              = data.tencentcloud_availability_zones_by_product.all.zones[0].name
  worker_instance_type = data.tencentcloud_instance_types.worker.instance_types[0].instance_type
  image_id             = data.tencentcloud_images.centos78.images[0].image_id

  key_id               = tencentcloud_key_pair.public_key.id
}


data "tencentcloud_availability_zones_by_product" "all" {
  product = "cvm"
}
data "tencentcloud_instance_types" "worker" {
  cpu_core_count    = var.worker_cpu_cores
  memory_size       = var.worker_memory_GB
  exclude_sold_out  = true
  filter {
    name   = "zone"
    values = [local.az_name]
  }
  filter {
    name   = "instance-family"
    values = ["S2"]
  }
}
data "tencentcloud_images" "centos78" {
  image_type = ["PUBLIC_IMAGE"]
  os_name    = "CentOS 7.8 64bit"
}


resource "tls_private_key" "tls_key_pair" {
  algorithm = "RSA"
  rsa_bits  = 2048
}
resource "local_sensitive_file" "private_key_file" {
  content  = tls_private_key.tls_key_pair.private_key_openssh
  filename = "${path.root}/tke_worker_${terraform.workspace}.key"
}
resource "tencentcloud_key_pair" "public_key" {
  key_name   = "KEY_TKE_${terraform.workspace}"

  public_key = tls_private_key.tls_key_pair.public_key_openssh
}

resource "tencentcloud_vpc" "vpc" {
  name       = "VPC_TKE_${terraform.workspace}"
  cidr_block = "10.0.0.0/16"
}
resource "tencentcloud_subnet" "subnet" {
  name              = "SUBNET_TKE_${terraform.workspace}"
  availability_zone = local.az_name
  vpc_id            = tencentcloud_vpc.vpc.id
  cidr_block        = "10.0.0.0/16"
}

resource "tencentcloud_security_group" "sec_grp" {
  name       = "${terraform.workspace}_CODING_DevOps_Sec_Grp_Deployer"
}
resource "tencentcloud_security_group_lite_rule" "sec_grp_rule" {
  security_group_id = tencentcloud_security_group.sec_grp.id

  ingress = [
    "ACCEPT#10.0.0.0/16#ALL#ALL",
    "ACCEPT#0.0.0.0/0#443#TCP",
  ]

  egress = [
    "ACCEPT#0.0.0.0/0#ALL#ALL",
  ]
}

resource "tencentcloud_kubernetes_cluster" "tke_cluster" {
  cluster_name                    = "TKE_${terraform.workspace}"

  vpc_id                          = tencentcloud_vpc.vpc.id
  cluster_cidr                    = "172.16.0.0/16"
  cluster_version                 = var.k8s_version
  cluster_os                      = "centos7.8.0_x64"
  container_runtime               = "containerd"
  cluster_max_pod_num             = 32
  cluster_max_service_num         = 32
  cluster_deploy_type             = "MANAGED_CLUSTER"
  cluster_internet                = true
  cluster_internet_security_group = tencentcloud_security_group.sec_grp.id

  worker_config {
    count                      = 1
    availability_zone          = local.az_name
    subnet_id                  = tencentcloud_subnet.subnet.id
    instance_type              = local.worker_instance_type
    system_disk_type           = "CLOUD_SSD"
    system_disk_size           = 60
    img_id                     = local.image_id
    key_ids                    = [local.key_id]

    public_ip_assigned         = true
    internet_max_bandwidth_out = 10
    internet_charge_type       = "TRAFFIC_POSTPAID_BY_HOUR"

    enhanced_security_service  = false
    enhanced_monitor_service   = false

    data_disk {
      disk_type = "CLOUD_PREMIUM"
      disk_size = 50
    }
  }
}
data "tencentcloud_instances" "worker" {
  instance_id = tencentcloud_kubernetes_cluster.tke_cluster.worker_instances_list[0].instance_id
}


output "tke_cluster" {
  value = tencentcloud_kubernetes_cluster.tke_cluster
}
output "worker_node" {
  value = data.tencentcloud_instances.worker.instance_list[0]
}
output "private_key_file" {
  value = local_sensitive_file.private_key_file
}
