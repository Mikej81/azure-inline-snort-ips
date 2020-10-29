# Azure Inline Snort IPS

Example / Test repo for Snort Inline IPS on Ubuntu in Azure using cloud-init, netplan, and terraform.

Give cloud-init a few minutes to run to finish download / compiling.  Runs in AFPacket Inline with Eth1:Eth2.

```bash
terraform init
terraform plan
terraform apply -auto-approve
```

Once Terraform completes, you can verify cloud-init status by SSH to the management interface.

```bash
cloud-init status --long
```

If you cant wait and want to see whats happening.

```bash
tail -f /var/log/cloud-init-output.log
```

Verify snort is running.

```bash
ps -ef | grep snort
```

Configure your variables as needed.

```HCL
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
```

I hate yaml...

```yaml
#cloud-config

write_files:
  - path: /etc/netplan/90-hotplug-azure.yaml
    content: |
      network:
        version: 2
        ethernets:
          eth0:
            dhcp4: true
            dhcp4-overrides:
             route-metric: 100
            dhcp6: false
            match:
              driver: hv_netvsc
              name: enp1*
            set-name: eth0
          eth1:
            dhcp4: true
            dhcp4-overrides:
              route-metric: 200
            dhcp6: false
            match:
              driver: hv_netvsc
              name: enp2*
            set-name: eth1
          eth2:
            dhcp4: true
            dhcp4-overrides:
              route-metric: 300
            dhcp6: false
            match:
              driver: hv_netvsc
              name: enp3*
            set-name: eth2
  - path: /etc/networkd-dispatcher/routable.d/10-disable-offloading
    content: |
      #!/bin/sh
      ethtool -K eth1 gro off lro off
      ethtool -K eth2 gro off lro off
  - path: /etc/networkd-dispatcher/dormant.d/promisc_bridge
    content: |
      #!/bin/sh
      set -e
      if [ "$IFACE" = br0 ]; then
      # no networkd-dispatcher event for 'carrier' on the physical interface
      ip link set eth1 up promisc on
      ip link set eth2 up promisc on
      fi
  - path: cat /etc/snort/rules/icmp.rules
    content: |
      alert icmp any any -> any any (msg:"ICMP Packet"; sid:477; rev:3;)

apt:
  primary:
    - arches: [default]
      search_dns: True
package_upgrade: true
packages:
  - build-essential
  - bridge-utils
  - libpcap-dev
  - libpcre3-dev
  - libdumbnet-dev
  - bison
  - flex
  - zlib1g-dev
  - liblzma-dev
  - openssl
  - libssl-dev
  - ethtool
  - autoconf
  - libtool
  - libtool-bin
  - pkg-config
  - gcc
  - zlib1g-dev
  - libluajit-5.1-dev
  - libnghttp2-dev
  - libdnet
  - git
  - libcrypt-ssleay-perl
  - liblwp-useragent-determined-perl

runcmd:
  - sudo chmod +x /etc/networkd-dispatcher/routable.d/10-disable-offloading
  - sudo chmod +x /etc/networkd-dispatcher/dormant.d/promisc_bridge
  - sudo apt autoremove -y
  - sudo mkdir /etc/snort
  - sudo mkdir /etc/snort/rules
  - sudo mkdir /var/log/snort
  - sudo mkdir -p /home/root/snort_src
  - cd /home/root/snort_src
  - [wget, "https://www.snort.org/downloads/snort/daq-2.0.7.tar.gz"]
  - [wget, "https://www.snort.org/downloads/snort/snort-2.9.16.1.tar.gz"]
  - [wget, "https://www.snort.org/downloads/community/community-rules.tar.gz"]
  - git clone https://github.com/John-Lin/docker-snort.git
  - tar -xvzf daq-2.0.7.tar.gz
  - tar -xvzf snort-2.9.16.1.tar.gz
  - tar -xvzf community-rules.tar.gz
  - cd /home/root/snort_src/daq-2.0.7
  - autoreconf -f -i
  - ./configure
  - make
  - sudo make install
  - cd /home/root/snort_src/snort-2.9.16.1
  - autoreconf -f -i
  - ./configure --enable-sourcefire
  - make
  - sudo make install
  - sudo ldconfig
  - sudo ln -s /usr/local/bin/snort /usr/sbin/snort
  - sudo mkdir -p /usr/local/lib/snort_dynamicrules
  - sudo cp /home/root/snort_src/snort-2.9.16.1/etc/* /etc/snort/
  - sudo touch /etc/snort/rules/white_list.rules /etc/snort/rules/black_list.rules
  - sudo cp /home/root/snort_src/docker-snort/snortrules-snapshot-2972/rules/* /etc/snort/rules
  - sudo sed -i 's/..\/rules/\/etc\/snort\/rules/g' /etc/snort/snort.conf
  - "sudo sed -i 's/# config daq: <type>/ config daq: afpacket/g' /etc/snort/snort.conf"
  - "sudo sed -i 's/# config daq_mode: <mode>/config daq_mode: inline/g' /etc/snort/snort.conf"
  - sudo /usr/local/bin/pulledpork.pl -V
  - sudo chmod +x /usr/lib/networkd-dispatcher/routable.d/10-disable-lrogro
  - sudo netplan --debug generate
  - sudo netplan apply
  - sudo snort -D -c /etc/snort/snort.conf -Q -i eth1:eth2

final_message: "The system is finally up, after $UPTIME seconds"
```
