##############################################################################
# IBM Cloud Provider
##############################################################################

provider "ibm" {
  ibmcloud_api_key = var.ibmcloud_api_key
  region           = var.region
  ibmcloud_timeout = 60
}

##############################################################################


##############################################################################
# VPC Module
##############################################################################

module "ez_vpc" {
  source                  = "./ez_vpc_cluster"
  prefix                  = var.prefix
  region                  = var.region
  resource_group          = var.resource_group
  tags                    = var.tags
  roks_cluster_version    = var.roks_cluster_version
  machine_type            = var.machine_type
  workers_per_zone        = var.workers_per_zone
  create_new_cos_instance = var.create_new_cos_instance
  object_storage_name     = var.object_storage_name
  object_storage_plan     = var.object_storage_plan
  use_public_gateways     = var.use_public_gateways
  allow_inbound_traffic   = var.allow_inbound_traffic
  classic_access          = var.classic_access
  override                = var.override
}

##############################################################################