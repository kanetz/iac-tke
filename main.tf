module "provisioning" {
  source = "./modules/provisioning"
}

resource "time_static" "start_time" {}
resource "time_static" "end_time" {
  triggers = {
    tke_cluster_ready = length(module.provisioning.tke_cluster)
    worker_node_ready = length(module.provisioning.worker_node)
    private_key_ready = length(module.provisioning.private_key_file)
  }
}
locals {
  elapsed_time_unix    = time_static.end_time.unix - time_static.start_time.unix
  elapsed_time_hours   = floor(local.elapsed_time_unix / 3600)
  elapsed_time_minutes = floor(local.elapsed_time_unix % 3600 / 60)
  elapsed_time_seconds = local.elapsed_time_unix % 60
  elapsed_time_message    = format("%s%s%s",
    local.elapsed_time_hours > 0 ? "${local.elapsed_time_hours}h" : "",
    (local.elapsed_time_hours > 0 || local.elapsed_time_minutes > 0) ? "${local.elapsed_time_minutes}m" : "",
    "${local.elapsed_time_seconds}s"
  )
}

output "_01_total_elapsed_time" {
  value = local.elapsed_time_message
}
output "_02_cluster_external_endpoint" {
  value = module.provisioning.tke_cluster.cluster_external_endpoint
}
output "_03_kube_config" {
  value = module.provisioning.tke_cluster.kube_config
}
output "_04_ssh_to_node" {
  value = "ssh -i ${abspath(module.provisioning.private_key_file.filename)} root@${module.provisioning.worker_node.public_ip}"
}
