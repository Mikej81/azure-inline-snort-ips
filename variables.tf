# Azure Environment
variable projectPrefix {
  type        = string
  description = "REQUIRED: Prefix to prepend to all objects created, minus Windows Jumpbox"
  default     = "C92E3"
}
variable adminUserName {
  type        = string
  description = "REQUIRED: Admin Username for All systems"
  default     = "xadmin"
}
variable adminPassword {
  type        = string
  description = "REQUIRED: Admin Password for all systems"
  default     = "pleaseUseVault123!!"
}
variable location {
  type        = string
  description = "REQUIRED: Azure Region: usgovvirginia, usgovarizona, etc"
  default     = "usgovvirginia"
}
variable region {
  type        = string
  description = "Azure Region: US Gov Virginia, US Gov Arizona, etc"
  default     = "USGov Virginia"
}

# NETWORK
variable cidr {
  description = "REQUIRED: VNET Network CIDR"
  default     = "10.90.0.0/16"
}

variable subnets {
  type        = map(string)
  description = "REQUIRED: Subnet CIDRs"
  default = {
    "management"  = "10.90.0.0/24"
    "external"    = "10.90.1.0/24"
    "internal"    = "10.90.2.0/24"
    "vdms"        = "10.90.3.0/24"
    "inspect_ext" = "10.90.4.0/24"
    "inspect_int" = "10.90.5.0/24"
    "waf_ext"     = "10.90.6.0/24"
    "waf_int"     = "10.90.7.0/24"
    "application" = "10.90.10.0/24"
  }
}

# Example IPS private ips
variable ips01ext { default = "10.90.4.4" }
variable ips01int { default = "10.90.5.4" }
variable ips01mgmt { default = "10.90.0.8" }

# BIGIP Instance Type, DS5_v2 is a solid baseline for BEST
variable instanceType { default = "Standard_DS5_v2" }

variable dns_server {
  type        = string
  description = "REQUIRED: Default is set to Azure DNS."
  default     = "168.63.129.16"
}

variable ntp_server { default = "time.nist.gov" }
variable timezone { default = "UTC" }
variable onboard_log { default = "/var/log/startup-script.log" }