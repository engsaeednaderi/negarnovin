# Troubleshooting Network Connectivity on an Ubuntu VPS

This runbook covers first-line checks for an Ubuntu VPS that loses network connectivity after a package upgrade, kernel change, or operating-system release upgrade.

It is written for administrators with console or out-of-band access. Commands that change network configuration can disconnect a remote session. Make a backup and ensure console access before applying changes.

## 1. Record the current network state

Run these read-only checks first:

```bash
ip -br link
ip -br address
ip route
ip rule
ip neigh
```

Confirm that the expected interface is present, has the expected address and prefix, and has a default route through the correct gateway.

Do not assume the interface is always named `eth0`. Names such as `ens3`, `ens18`, and `ens160` are common in virtualized environments.

## 2. Check DNS separately from IP connectivity

Test a known IP address first, then test name resolution:

```bash
ping -c 4 1.1.1.1
resolvectl status
resolvectl query ubuntu.com
```

Interpretation:

- If the IP test fails, investigate addressing, routing, gateway reachability, firewall rules, and the provider network.
- If the IP test succeeds but name resolution fails, investigate resolver configuration.
- A failed ICMP ping alone does not prove that all network traffic is unavailable; verify with an appropriate TCP test as well.

## 3. Identify which network service manages the interface

Check which network services are active:

```bash
systemctl is-active systemd-networkd
systemctl is-active NetworkManager
networkctl list
nmcli device status
```

A host commonly uses Netplan as the configuration layer and either systemd-networkd or NetworkManager as the renderer. Do not configure the same interface independently in multiple network managers.

## 4. Inspect Netplan configuration

List the Netplan files:

```bash
ls -l /etc/netplan/
sudo netplan get
```

Inspect the YAML files and verify:

- Interface match/name
- Static address and prefix
- Default route and gateway
- DNS nameservers
- Renderer
- YAML indentation

For a static configuration, confirm the gateway and prefix with the VPS provider's network documentation. Some providers use point-to-point addresses or a /32 prefix and require an explicit route to the gateway. Do not copy a gateway or prefix from another server.

## 5. Validate before applying

Generate and validate the configuration:

```bash
sudo netplan generate
```

If the configuration is correct and console access is available, use Netplan's rollback-capable try mode:

```bash
sudo netplan try
```

Confirm the configuration only after connectivity has been verified. If the session is remote and you cannot recover through a console, do not apply a risky network change.

## 6. Inspect service logs

For systemd-networkd:

```bash
sudo journalctl -b -u systemd-networkd --no-pager -n 100
```

For NetworkManager:

```bash
sudo journalctl -b -u NetworkManager --no-pager -n 100
```

Also inspect kernel messages for virtual NIC or driver errors:

```bash
sudo journalctl -k -b --no-pager | grep -Ei 'virtio|network|link is|rename|firmware|driver'
```

## 7. Check firewall and packet counters

Read interface counters:

```bash
ip -s link
```

Inspect the active firewall backend before changing rules:

```bash
sudo nft list ruleset
sudo ufw status verbose
```

Do not flush firewall rules as a generic troubleshooting step. First identify which ruleset is active and whether a rule is responsible.

## 8. Verify connectivity in layers

Use this order to isolate the fault:

1. Interface is up.
2. IP address and prefix are correct.
3. Local routing table contains the expected routes.
4. Gateway is reachable where the provider's network design permits it.
5. DNS resolution works.
6. Required TCP services are reachable.
7. The guest firewall and upstream filtering are not blocking the traffic.

Record command output before and after each controlled change. Change one variable at a time.

## Safety notes

- Keep hypervisor console or provider rescue access available before changing remote network configuration.
- Do not guess the gateway, prefix, interface name, or DNS resolver.
- Do not combine a distribution upgrade with multiple unrelated network changes.
- Back up `/etc/netplan/` before editing it.
- A reboot should not be the first diagnostic step when a live console can provide more information.

## Related Negarnovin resources

- [Negarnovin official website](https://negarnovin.com/)
- [Virtual server services](https://negarnovin.com/vps/)
- [Contact and support](https://negarnovin.com/contact-us/)

This is a general operational runbook. Validate every command and network assumption against the specific Ubuntu release, provider network design, and production environment before use.
