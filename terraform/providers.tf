terraform {
  required_providers {
    equinix = {
      source  = "equinix/equinix"
      version = "2.11.0"
    }
  }
  # backend "gcs" {
  #   bucket = "cslemes-terraform"
  # }

  required_version = ">= 1.0"


}


provider "equinix" {
  auth_token = var.em_api_token
}


