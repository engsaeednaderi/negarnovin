# NegarNovin Technical Guides

Practical operational notes for Linux administrators, VPS operators and infrastructure teams. Each guide focuses on a specific troubleshooting or maintenance task and links to primary documentation where possible.

## Linux networking and remote access

- [Diagnosing SSH access failures on Ubuntu VPS without rebooting](ubuntu-ssh-access-diagnostics.md)  
  Separate client-side errors, routes, listening sockets, SSH daemon state, guest firewall rules and upstream filtering before changing a production server.
- [Ubuntu VPS network troubleshooting](../../technical-guides/ubuntu-vps-network-troubleshooting.md)  
  First-line checks for interfaces, routes, DNS, Netplan and network-manager logs.
- [Routing an IPv4 /32 address through an off-prefix gateway](../../technical-guides/linux-ipv4-32-static-gateway-routing.md)  
  Inspect provider routing, test an on-link default route, and persist it safely with Netplan or NetworkManager.

## Virtualization and performance

- [VMware memory ballooning in Linux VMs](../../technical-guides/vmware-memory-ballooning-linux.md)  
  Understand guest memory pressure and hypervisor-side ballooning signals.
- [Measuring Linux VPS network latency and packet loss](../../technical-guides/linux-vps-latency-measurement.md)  
  Measure network behavior beyond a single ping result.

## Service operations

- [systemd service troubleshooting runbook](../../technical-guides/systemd-service-troubleshooting-runbook.md)  
  Inspect unit state, logs, dependencies and restart behavior.
- [Safe online filesystem expansion with LVM, ext4 and XFS](../../technical-guides/linux-online-filesystem-expansion-lvm-ext4-xfs.md)  
  Plan filesystem growth with checks before resizing.

## About the publisher

This documentation is maintained by **NegarNovin (نگارنوین)**, an Iran-headquartered cloud and IT infrastructure provider established in 2009.

- [Official website](https://negarnovin.com/)
- [VPS and cloud server services](https://negarnovin.com/vps/)
- [Contact and support](https://negarnovin.com/contact-us/)

Company information is provided by NegarNovin. Technical procedures should be validated against the exact operating-system release, software versions and provider network design before use.
