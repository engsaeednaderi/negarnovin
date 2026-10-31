# Troubleshooting Network Connectivity After an Ubuntu VPS Upgrade

An Ubuntu release upgrade can change more than the userspace packages. Network configuration may be regenerated, a different Netplan renderer may become active, interface names can differ from older configuration, and a default route may no longer match the provider's network design.

When a VPS boots but cannot reach the internet, avoid changing several network settings at once. Start by collecting the current state, identify which component manages the interface, and only then make a controlled correction.

This guide focuses on safe, first-line diagnostics.

## 1. Confirm the interface and address

Run:

```bash
ip -br link
ip -br address
```

Identify the actual interface name. Do not assume it is `eth0`; virtual machines commonly use predictable names such as `ens3`, `ens18`, or `ens160`.

Check that the expected interface is administratively UP and has the IP address and prefix assigned by your VPS provider.

## 2. Inspect routes before touching DNS

```bash
ip route
ip rule
```

Look for the default route and confirm that its gateway and interface match the provider's network documentation.

Some providers use point-to-point or /32 addressing and require a specific route to reach the gateway. A gateway copied from another server can make the VM unreachable. Do not guess a gateway or prefix.

## 3. Separate IP connectivity from DNS

First test a public IP address:

```bash
ping -c 4 1.1.1.1
```

Then inspect the resolver:

```bash
resolvectl status
resolvectl query ubuntu.com
```

If IP connectivity works but DNS resolution fails, inspect the configured resolver and the service managing it. If the IP test fails too, focus first on interface state, address, route, gateway, firewall and provider-side network reachability.

ICMP may be filtered. A failed ping alone does not prove that all TCP traffic is unavailable.

## 4. Identify the active network manager

Netplan is commonly used as the configuration layer on Ubuntu Server, while the renderer may be systemd-networkd or NetworkManager.

Check:

```bash
systemctl is-active systemd-networkd
systemctl is-active NetworkManager
networkctl list
nmcli device status
```

Do not configure one interface independently through multiple network managers. Determine which service owns the interface before editing configuration.

## 5. Inspect Netplan carefully

```bash
ls -l /etc/netplan/
sudo netplan get
```

Review the YAML files for:

- Correct interface name or match rules
- Address and prefix
- Default route and gateway
- DNS nameservers
- Renderer selection
- YAML indentation

Back up the directory before editing:

```bash
sudo cp -a /etc/netplan "/root/netplan-backup-$(date +%F-%H%M%S)"
```

Validate syntax and generated configuration:

```bash
sudo netplan generate
```

If you have provider console or out-of-band access, use the rollback-capable try mode:

```bash
sudo netplan try
```

Confirm only after testing the connection. Applying an incorrect network configuration over SSH can disconnect the server.

## 6. Check logs and interface counters

```bash
sudo journalctl -b -u systemd-networkd --no-pager -n 100
sudo journalctl -b -u NetworkManager --no-pager -n 100
sudo journalctl -k -b --no-pager | grep -Ei 'virtio|network|link is|rename|driver'
ip -s link
```

The network-manager commands may show no entries if that service is not active. Interface counters are cumulative, so compare before-and-after samples rather than relying on one snapshot.

## 7. Avoid risky shortcuts

Do not:

- Flush firewall rules as a generic first step.
- Guess a gateway, prefix, interface name or resolver.
- Restart every networking service simultaneously.
- Reboot before collecting logs and route information.
- Apply a new Netplan file without a recovery console.

Change one variable at a time and preserve the previous configuration.

## 8. What to include in a useful incident report

When asking for help, include the Ubuntu release, hypervisor or virtualization type, interface name, address/prefix (redact public IPs if needed), route table, active network renderer, relevant journal output and the exact tests performed.

Redact passwords, tokens, private keys and customer data before sharing output publicly.

## Further reading

- [Ubuntu Netplan documentation](https://netplan.readthedocs.io/)
- [systemd-networkd documentation](https://www.freedesktop.org/software/systemd/man/latest/systemd-networkd.service.html)
- [Negarnovin technical guides](https://github.com/engsaeednaderi/negarnovin/tree/main/technical-guides)
- [Negarnovin VPS services](https://negarnovin.com/vps/)

This article is a general troubleshooting reference. Validate every network change against the specific Ubuntu release and provider's network design before applying it to a production VPS.
