##############################################################################
# Resource Group where VPC Resources Will Be Created
##############################################################################

data "ibm_resource_group" "resource_group" {
  name = var.resource_group
}

##############################################################################


##############################################################################
# Create VPC
##############################################################################

module "vpc" {
  source                      = "./vpc"
  resource_group_id           = data.ibm_resource_group.resource_group.id
  region                      = var.region
  tags                        = var.tags
  prefix                      = lookup(local.override, "prefix", var.prefix)
  vpc_name                    = lookup(local.override, "vpc_name", local.config.vpc_name)
  classic_access              = lookup(local.override, "classic_access", local.config.classic_access)
  network_acls                = lookup(local.override, "network_acls", local.acls)
  use_public_gateways         = lookup(local.override, "use_public_gateways", local.config.use_public_gateways)
  subnets                     = lookup(local.override, "subnets", local.config.subnets)
  use_manual_address_prefixes = lookup(local.override, "use_manual_address_prefixes", null)
  default_network_acl_name    = lookup(local.override, "default_network_acl_name", null)
  default_security_group_name = lookup(local.override, "default_security_group_name", null)
  default_routing_table_name  = lookup(local.override, "default_routing_table_name", null)
  address_prefixes            = lookup(local.override, "address_prefixes", null)
  routes                      = lookup(local.override, "routes", [])
  vpn_gateways                = lookup(local.override, "vpn_gateways", [])
}

##############################################################################

##############################################################################
# Object Storage
##############################################################################

data "ibm_resource_instance" "cos" {
  count             = var.create_new_cos_instance ? 0 : 1
  name              = var.object_storage_name
  location          = "global"
  resource_group_id = data.ibm_resource_group.resource_group.id
  service           = "cloud-object-storage"
}

resource "ibm_resource_instance" "cos" {
  count             = var.create_new_cos_instance ? 1 : 0
  name              = var.object_storage_name
  resource_group_id = data.ibm_resource_group.resource_group.id
  service           = "cloud-object-storage"
  location          = "global"
  plan              = var.object_storage_plan
  tags              = (var.tags != null ? var.tags : null)
}

locals {
  cos_id = (
    var.create_new_cos_instance
    ? ibm_resource_instance.cos[0].id
    : data.ibm_resource_instance.cos[0].id
  )
  kube_version = (
    var.roks_cluster_version == "default"
    ? "${data.ibm_container_cluster_versions.cluster_versions.valid_openshift_versions[length(data.ibm_container_cluster_versions.cluster_versions.valid_openshift_versions) - 1]}_openshift"
    : var.roks_cluster_version
  )
  cluster_subnets = {
    for subnet in toset(
      lookup(local.override, "subnets", local.config.cluster.subnets)
    ) :
    (subnet) => [
      for vpc_subnet in module.vpc.subnet_zone_list :
      vpc_subnet if vpc_subnet.name == subnet
    ][0]
  }
}

##############################################################################


##############################################################################
# Cluster
##############################################################################

resource "ibm_container_vpc_cluster" "cluster" {
  vpc_id                          = module.vpc.vpc_id
  resource_group_id               = data.ibm_resource_group.resource_group.id
  tags                            = (var.tags != null ? var.tags : null)
  cos_instance_crn                = local.cos_id
  name                            = lookup(local.override, "name", local.config.cluster.name)
  kube_version                    = lookup(local.override, "kube_version", local.config.cluster.kube_version)
  flavor                          = lookup(local.override, "machine_type", local.config.cluster.machine_type)
  disable_public_service_endpoint = lookup(local.override, "disable_public_service_endpoint", local.config.cluster.disable_public_service_endpoint)
  worker_count                    = lookup(local.override, "workers_per_zone", local.config.cluster.workers_per_zone)
  dynamic "zones" {
    for_each = local.cluster_subnets
    content {
      subnet_id = zones.value["id"]
      name      = zones.value["zone"]
    }
  }
}

##############################################################################