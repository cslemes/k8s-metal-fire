resource "equinix_metal_device" "k8s_master" {
  count            = var.k8s_master.num_instances
  hostname         = "k8s-master-${count.index + 1}"
  plan             = var.k8s_master.plan
  metro            = var.em_region
  operating_system = var.k8s_master.operating_system
  billing_cycle    = var.billing_cycle
  project_id       = var.em_project_id

  tags = ["kubernetes", "master"]

}

resource "equinix_metal_device" "k8s_worker" {
  count            = var.k8s_nodes.num_instances
  hostname         = "k8s-worker-${count.index + 1}"
  plan             = var.k8s_nodes.plan
  metro            = var.em_region
  operating_system = var.k8s_nodes.operating_system
  billing_cycle    = var.billing_cycle
  project_id       = var.em_project_id

  tags = ["kubernetes", "worker"]

}


