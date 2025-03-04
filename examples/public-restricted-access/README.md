<!-- BEGIN_TF_DOCS -->
# Public restricted access example

This example deploys the module with public network access enabled, but restricted to specific IP addresses and subnets using service endpoints.

```hcl
terraform {
  required_version = "~> 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.14"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

locals {
  prefix = "resPub"
  skus   = ["Basic", "Standard", "Premium"]
}

module "regions" {
  source  = "Azure/regions/azurerm"
  version = ">= 0.3.0"

  recommended_regions_only = true
}

resource "random_integer" "region_index" {
  max = length(module.regions.regions) - 1
  min = 0
}

module "naming" {
  source  = "Azure/naming/azurerm"
  version = ">= 0.3.0"
}

resource "azurerm_resource_group" "example" {
  location = module.regions.regions[random_integer.region_index.result].name
  name     = "${module.naming.resource_group.name_unique}-${local.prefix}"
}

resource "azurerm_virtual_network" "example" {
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.example.location
  name                = "${module.naming.virtual_network.name_unique}-${local.prefix}"
  resource_group_name = azurerm_resource_group.example.name
}

resource "azurerm_subnet" "example" {
  address_prefixes     = ["10.0.0.0/24"]
  name                 = module.naming.subnet.name_unique
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  service_endpoints    = ["Microsoft.ServiceBus"]
}

module "servicebus" {
  source = "../../"

  for_each = toset(local.skus)

  sku                           = each.value
  resource_group_name           = azurerm_resource_group.example.name
  location                      = azurerm_resource_group.example.location
  name                          = "${module.naming.servicebus_namespace.name_unique}-${each.value}-${local.prefix}"
  public_network_access_enabled = true

  network_rule_config = {
    trusted_services_allowed = true
    default_action           = "Deny"
    cidr_or_ip_rules         = ["168.125.123.255", "170.0.0.0/24"]

    network_rules = each.value == "Premium" ? [
      {
        subnet_id = azurerm_subnet.example.id
      }
    ] : null
  }
}
```

<!-- markdownlint-disable MD033 -->
## Requirements

The following requirements are needed by this module:

- <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) (~> 1.5)

- <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) (~> 4.14)

- <a name="requirement_random"></a> [random](#requirement\_random) (~> 3.6)

## Providers

The following providers are used by this module:

- <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) (~> 4.14)

- <a name="provider_random"></a> [random](#provider\_random) (~> 3.6)

## Resources

The following resources are used by this module:

- [azurerm_resource_group.example](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) (resource)
- [azurerm_subnet.example](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) (resource)
- [azurerm_virtual_network.example](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network) (resource)
- [random_integer.region_index](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/integer) (resource)

<!-- markdownlint-disable MD013 -->
## Required Inputs

No required inputs.

## Optional Inputs

No optional inputs.

## Outputs

No outputs.

## Modules

The following Modules are called:

### <a name="module_naming"></a> [naming](#module\_naming)

Source: Azure/naming/azurerm

Version: >= 0.3.0

### <a name="module_regions"></a> [regions](#module\_regions)

Source: Azure/regions/azurerm

Version: >= 0.3.0

### <a name="module_servicebus"></a> [servicebus](#module\_servicebus)

Source: ../../

Version:

<!-- markdownlint-disable-next-line MD041 -->
## Data Collection

The software may collect information about you and your use of the software and send it to Microsoft. Microsoft may use this information to provide services and improve our products and services. You may turn off the telemetry as described in the repository. There are also some features in the software that may enable you and Microsoft to collect data from users of your applications. If you use these features, you must comply with applicable law, including providing appropriate notices to users of your applications together with a copy of Microsoft’s privacy statement. Our privacy statement is located at <https://go.microsoft.com/fwlink/?LinkID=824704>. You can learn more about data collection and use in the help documentation and our privacy statement. Your use of the software operates as your consent to these practices.
<!-- END_TF_DOCS -->