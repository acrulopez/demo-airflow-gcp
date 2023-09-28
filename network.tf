
locals {
  subnets = {
    "01" = {
      ip          = "10.0.0.0/16"
      region      = "europe-west1"
      description = "Subnet to be used in the D6 GKE cluster"
      secondary_ranges = {
        gke-pods     = "10.200.0.0/16"
        gke-services = "10.201.0.0/16"
      }
    }
  }
}


module "network" {
  source  = "terraform-google-modules/network/google"
  version = "7.0.0"

  project_id   = var.project_id
  network_name = "vpc-test"
  description  = "Network to use as shared VPC for projects"

  shared_vpc_host = false
  routing_mode    = "GLOBAL"

  routes = []

  subnets = [for unique_number, subnet in local.subnets : {
    subnet_name           = "subnet-${subnet.region}-${unique_number}"
    subnet_ip             = subnet.ip
    subnet_region         = subnet.region
    subnet_private_access = "true"
    subnet_flow_logs      = "true"
    description           = subnet.description
  }]

  secondary_ranges = { for unique_number, subnet in local.subnets :
    "subnet-${subnet.region}-${unique_number}" => [
      for range_name, range in subnet.secondary_ranges : {
        range_name    = range_name
        ip_cidr_range = range
      }
    ]
  }
}


module "cloud_router" {
  source  = "terraform-google-modules/cloud-router/google"
  version = "5.0.1"

  name    = "router-shared-host"
  project = var.project_id
  region  = "europe-west1"
  network = module.network.network_name
  nats = [
    {
      name = "nat-shared-host"
    }
  ]
}


resource "google_compute_global_address" "private_ip_alloc" {
  project       = var.project_id
  name          = "airflow-db-ip"
  address_type  = "INTERNAL"
  purpose       = "VPC_PEERING"
  prefix_length = 16
  network       = module.network.network_id
  address       = "10.81.0.0"
}

resource "google_service_networking_connection" "vpc_connection" {
  network                 = module.network.network_id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_alloc.name]
}
