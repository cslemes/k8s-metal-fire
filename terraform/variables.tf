variable "em_api_token" {
  description = "Equinix Metal API Key"
  type        = string
}

variable "em_project_id" {
  description = "Equinix Metal Project ID"
  type        = string
}

variable "em_region" {
  description = "Equinix Metal region to use"
  type        = string
}


variable "billing_cycle" {
  description = "value of billing cycle"
  type        = string

}

variable "k8s_nodes" {
  description = "k8s nodes"
  type = object({
    plan               = string
    ipxe_script_url    = optional(string)
    operating_system   = string
    num_instances      = number
    config_patch_files = optional(list(string), [])
    tags               = optional(list(string), [])

  })
}

variable "k8s_master" {
  description = "k8s master"
  type = object({
    plan               = string
    ipxe_script_url    = optional(string)
    operating_system   = string
    num_instances      = number
    config_patch_files = optional(list(string), [])
    tags               = optional(list(string), [])

  })
}



