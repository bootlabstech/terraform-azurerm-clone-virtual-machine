resource "azurerm_virtual_machine" "virtual_machine" {
  name                             = var.name
  location                         = var.location
  resource_group_name              = var.resource_group_name
  network_interface_ids            = [azurerm_network_interface.network_interface.id]
  vm_size                          = var.vm_size
  delete_os_disk_on_termination    = var.delete_os_disk_on_termination
  delete_data_disks_on_termination = var.delete_data_disks_on_termination

  # storage_image_reference {
  #   publisher = var.publisher
  #   offer     = var.offer
  #   sku       = var.sku
  #   version   = var.storage_image_version
  # }

     dynamic "os_profile_linux_config" {
    for_each = var.os_type == "Linux" ? [1] : []
    content {
      disable_password_authentication = var.disable_password_authentication
    }
  }

  dynamic "os_profile_windows_config" {
    for_each = var.os_type == "Windows" ? [1] : []
    content {
      
      provision_vm_agent = "true"
    }
  }

  storage_os_disk {
    name              = var.diskname
    caching           = var.caching
    create_option     = var.create_option
    managed_disk_type = var.managed_disk_type
    os_type           = var.os_type
    managed_disk_id   = var.managed_disk_id
  }

  # os_profile {
  #   computer_name  = var.name
  #   admin_username = var.admin_username
  #   admin_password = var.admin_password
  #   custom_data    = var.custom_data
  # }

  # dynamic "os_profile_linux_config" {
  #   for_each = var.os_type == "Linux" ? [1] : []
  #   content {
  #     disable_password_authentication = var.disable_password_authentication
  #   }
  # }

  # dynamic "os_profile_windows_config" {
  #   for_each = var.os_type == "Windows" ? [1] : []
  #   content {
  #     timezone = var.timezone
  #     provision_vm_agent = true
  #   }
    
  # }

  lifecycle {
    ignore_changes = [
      tags,
    ]
  }
  depends_on = [
    azurerm_network_interface.network_interface
  ]
}
resource "azurerm_network_interface" "network_interface" {
  name                = "${var.name}-nic"
  location            = var.location
  resource_group_name = var.resource_group_name
  ip_configuration {
    name                          = var.ip_name
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = var.private_ip_address_allocation
  }
}

resource "azurerm_network_security_group" "nsg" {
  name                = "${var.name}-nsg"
  location            = azurerm_virtual_machine.virtual_machine.location
  resource_group_name = azurerm_virtual_machine.virtual_machine.resource_group_name
}

resource "azurerm_network_security_rule" "nsg_rules" {
  for_each                    = var.nsg_rules
  name                        = each.value.name
  priority                    = each.value.priority
  direction                   = each.value.direction
  access                      = each.value.access
  protocol                    = each.value.protocol
  source_address_prefix       = each.value.source_address_prefix
  source_port_range           = each.value.source_port_range
  destination_address_prefix  = each.value.destination_address_prefix
  destination_port_range      = each.value.destination_port_range
  network_security_group_name = azurerm_network_security_group.nsg.name
  resource_group_name         = azurerm_virtual_machine.virtual_machine.resource_group_name
}

resource "azurerm_network_interface_security_group_association" "security_group_association" {
  network_interface_id      = azurerm_network_interface.network_interface.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}







# Getting existing recovery_services_vault to add vm as a backup item 
data "azurerm_recovery_services_vault" "services_vault" {
  name                = var.recovery_services_vault_name
  resource_group_name = var.services_vault_resource_group_name
}

data "azurerm_backup_policy_vm" "policy" {
  name                = "EnhancedPolicy"
  recovery_vault_name = data.azurerm_recovery_services_vault.services_vault.name
  resource_group_name = data.azurerm_recovery_services_vault.services_vault.resource_group_name
}
resource "azurerm_backup_protected_vm" "backup_protected_vm" {
  resource_group_name = data.azurerm_recovery_services_vault.services_vault.resource_group_name
  recovery_vault_name = data.azurerm_recovery_services_vault.services_vault.name
  source_vm_id        = azurerm_virtual_machine.virtual_machine.id
  backup_policy_id    = data.azurerm_backup_policy_vm.policy.id
  depends_on = [
    azurerm_virtual_machine.virtual_machine
  ]
}
# # Extention for startup ELK script
# resource "azurerm_virtual_machine_extension" "example" {
#   name                 = "${var.name}-s1agent"
#   virtual_machine_id   = azurerm_virtual_machine.virtual_machine.id
#   publisher            = "Microsoft.Compute"
#   type                 = "CustomScriptExtension"
#   type_handler_version = "1.10"

#   settings = <<SETTINGS
#     {
#       "fileUris": ["https://sharedsaelk.blob.core.windows.net/s1-data/s1-agent.ps1"],
#       "commandToExecute": "powershell -ExecutionPolicy Bypass -File s1-agent.ps1" 
#     }
# SETTINGS
# }