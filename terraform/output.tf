output "master_ips" {
  value = {
    for device in equinix_metal_device.k8s_master :
    device.hostname => {
      "public_ip"  = device.access_public_ipv4
      "private_ip" = device.access_private_ipv4
    }
  }
  description = "IP addresses of master nodes"
}

output "worker_ips" {
  value = {
    for device in equinix_metal_device.k8s_worker :
    device.hostname => {
      "public_ip"  = device.access_public_ipv4
      "private_ip" = device.access_private_ipv4
    }
  }
  description = "IP addresses of worker nodes"
}
