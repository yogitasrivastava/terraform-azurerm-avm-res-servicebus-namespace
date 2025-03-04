resource "azurerm_servicebus_namespace" "this" {
  location                      = var.location
  name                          = var.name
  resource_group_name           = var.resource_group_name
  sku                           = var.sku
  capacity                      = local.normalized_capacity
  local_auth_enabled            = var.local_auth_enabled
  minimum_tls_version           = var.minimum_tls_version
  premium_messaging_partitions  = local.normalized_premium_messaging_partitions
  public_network_access_enabled = var.public_network_access_enabled
  tags                          = var.tags

  dynamic "customer_managed_key" {
    for_each = var.sku == local.premium_sku_name && var.customer_managed_key != null ? [1] : []

    content {
      identity_id                       = var.customer_managed_key.user_assigned_identity.resource_id
      key_vault_key_id                  = local.normalized_cmk_key_url
      infrastructure_encryption_enabled = var.infrastructure_encryption_enabled
    }
  }
  dynamic "identity" {
    for_each = local.managed_identities.system_assigned_user_assigned

    content {
      type         = identity.value.type
      identity_ids = identity.value.user_assigned_resource_ids
    }
  }
  network_rule_set {
    default_action                = var.network_rule_config.default_action
    ip_rules                      = var.network_rule_config.cidr_or_ip_rules
    public_network_access_enabled = var.public_network_access_enabled
    trusted_services_allowed      = var.network_rule_config.trusted_services_allowed

    dynamic "network_rules" {
      for_each = var.sku == local.premium_sku_name ? var.network_rule_config.network_rules : []

      content {
        subnet_id                            = network_rules.value.subnet_id
        ignore_missing_vnet_service_endpoint = false
      }
    }
  }
  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }

  # These cases are handled in the normalized_xxx variables. Serves as unit testing in case of future changes to those variables
  lifecycle {
    precondition {
      condition     = var.sku != local.premium_sku_name ? local.normalized_premium_messaging_partitions == 0 : true
      error_message = "Premium messaging partitions requires Premium SKU"
    }
    precondition {
      condition     = var.network_rule_config.default_action == "Deny" && length(var.network_rule_config.cidr_or_ip_rules) == 0 && (var.sku != local.premium_sku_name || length(var.network_rule_config.network_rules) == 0) ? false : true
      error_message = "The 'network_rule_config.default_action' can only be set to 'Allow' if no 'network_rule_config.cidr_or_ip_rules' are set and no 'network_rule_config.network_rules' are set for Premium"
    }
    precondition {
      condition     = var.sku != local.premium_sku_name ? local.normalized_capacity == 0 : true
      error_message = "Capacity parameter requires Premium SKU"
    }
  }
}

resource "azurerm_servicebus_namespace_authorization_rule" "this" {
  for_each = var.authorization_rules

  name         = coalesce(each.value.name, each.key)
  namespace_id = azurerm_servicebus_namespace.this.id
  listen       = each.value.manage ? true : each.value.listen
  manage       = each.value.manage
  send         = each.value.manage ? true : each.value.send
}
