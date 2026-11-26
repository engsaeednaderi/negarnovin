# Routing an IPv4 /32 Address Through an Off-Prefix Gateway on a Linux VM

A Linux virtual machine can have a single public IPv4 address configured with a `/32` prefix. This is a valid host route, but it behaves differently from a conventional `/24` or `/23` subnet: the address itself does not imply that the gateway is on the same connected network.

A common failure is to add the address and a default route with a gateway that the kernel considers unreachable. Another is to apply a route that works until reboot because it was added with `ip route` but never persisted in the network manager.

This guide explains how to inspect the provider's routing model, test a temporary route, and then make the configuration persistent with Netplan or NetworkManager. It uses documentation-only addresses; replace them with the exact values supplied for the VM.

> **Safety:** changing a default route on a remote machine can terminate SSH. Use a hypervisor console, serial console or provider rescue path, keep a second session open, and have a tested rollback plan before applying changes.

## 1. Understand the addressing model

The examples use the following documentation addresses:

| Setting | Example |
|---|---|
| Interface | `ens3` |
| Guest IPv4 address | `203.0.113.10/32` |
| Provider gateway | `203.0.113.1` |
| DNS resolver 1 | `192.0.2.53` |
| DNS resolver 2 | `198.51.100.53` |

These addresses belong to ranges reserved for documentation. They are not usable public endpoints.

A `/32` prefix represents one IPv4 host address. It does not create a connected subnet containing the gateway. Whether an off-prefix gateway should be treated as directly reachable depends on the provider's network design. Some routed VPS designs require an explicit on-link default route; others use a different gateway or point-to-point model.

Do not infer the gateway from the guest address. Use the exact address, prefix, interface, and gateway published by the provider for that VM.

## 2. Capture the current state before changing anything

Start with read-only commands:

```bash
ip -br link
ip -br address
ip route show table main
ip rule show
ip route get 1.1.1.1
nmcli device status 2>/dev/null || true
networkctl list 2>/dev/null || true
```

Record the active interface name, current addresses, default route, route metrics and the service managing the interface. Do not configure the same connection independently through NetworkManager and systemd-networkd.

Check the current gateway and the route selected for an external destination:

```bash
ip route get 1.1.1.1
ip route get 1.1.1.1 from 203.0.113.10
```

The second command is useful after the address is configured. It asks the kernel to resolve the route using the specified source address.

Also inspect the provider portal or network documentation. Confirm whether the guest is expected to use a `/32`, whether the gateway is on-link, whether additional host routes are required, and whether the provider expects a specific source address.

## 3. Test a temporary route

Only after confirming the provider's intended topology, a temporary on-link default route can be tested with:

```bash
sudo ip address replace 203.0.113.10/32 dev ens3
sudo ip route replace default via 203.0.113.1 dev ens3 onlink
```

The `onlink` flag tells the kernel to treat the next hop as directly attached to the link even though it does not match the interface prefix. It does not create connectivity by itself and cannot compensate for a wrong gateway, missing provider-side route, blocked ARP/neighbor discovery, or upstream filtering.

Inspect the result:

```bash
ip -4 address show dev ens3
ip -4 route show
ip route get 1.1.1.1 from 203.0.113.10
ip neigh show dev ens3
```

If the route lookup is correct but traffic still fails, investigate the provider's layer-2/layer-3 design, neighbor resolution, source-address filtering and upstream firewall separately. A successful route lookup only proves that the local routing table selected a path; it does not prove end-to-end reachability.

Do not flush the routing table or remove unrelated policy routes as a troubleshooting shortcut.

## 4. Persist the configuration with Netplan

On Ubuntu systems using Netplan with the `networkd` renderer, a configuration can look like this:

```yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    ens3:
      dhcp4: false
      addresses:
        - 203.0.113.10/32
      routes:
        - to: default
          via: 203.0.113.1
          on-link: true
      nameservers:
        addresses:
          - 192.0.2.53
          - 198.51.100.53
```

Use the actual interface name and provider-assigned values. If a Netplan file already exists, edit the relevant interface definition rather than creating a second conflicting definition.

Validate the generated configuration before applying it:

```bash
sudo netplan get
sudo netplan generate
```

When console access is available, use the rollback-capable try mode:

```bash
sudo netplan try --timeout 120
```

Confirm only after a new SSH connection and the required application traffic both work. If the configuration is not confirmed, Netplan attempts to revert it. Keep out-of-band console access available; never treat automatic rollback as a substitute for recovery access.

## 5. Persist the route with NetworkManager

For a NetworkManager-managed interface, first identify the connection profile:

```bash
nmcli -f NAME,UUID,TYPE,DEVICE connection show
nmcli device status
```

After confirming the correct profile, use a manual IPv4 method and an explicit default route. The following is an example; `CONNECTION_NAME` must be replaced with the profile name:

```bash
sudo nmcli connection modify "CONNECTION_NAME" \
  ipv4.method manual \
  ipv4.addresses "203.0.113.10/32" \
  ipv4.routes "0.0.0.0/0 203.0.113.1 100 onlink=true" \
  ipv4.dns "192.0.2.53,198.51.100.53" \
  ipv4.ignore-auto-dns yes
```

This form defines the default route explicitly instead of relying on `ipv4.gateway`. NetworkManager supports route attributes, including `onlink`, in its IPv4 route setting. Verify the exact syntax against the NetworkManager version installed on the guest.

Changing an active profile can interrupt the connection. Apply it from a console or during a controlled maintenance window:

```bash
sudo nmcli connection up "CONNECTION_NAME"
```

Then inspect the resulting address and route:

```bash
ip -4 address show dev ens3
ip -4 route show
nmcli -f ipv4.method,ipv4.addresses,ipv4.routes,ipv4.gateway,ipv4.dns \
  connection show "CONNECTION_NAME"
```

Do not configure a default gateway both through `ipv4.gateway` and a separate manual default route unless there is a deliberate reason and the resulting route metrics have been checked.

## 6. Verify more than a ping

Use multiple checks, each answering a different question:

```bash
ip route get 1.1.1.1 from 203.0.113.10
ip neigh show dev ens3
ping -c 3 -I 203.0.113.10 1.1.1.1
getent ahostsv4 example.com
curl -4 --connect-timeout 5 -I https://example.com/
```

Interpret the results carefully:

- A correct `ip route get` result shows the local route decision, not remote reachability.
- An incomplete neighbor entry can indicate that the next hop is not resolving at layer 2, but some provider designs use proxy ARP or other routing arrangements.
- ICMP can be filtered. A failed ping does not establish that TCP is unavailable.
- Successful DNS resolution does not prove that the default route is correct for every source address.
- Test the actual service ports and source addresses that the workload needs.

If the VM has multiple public addresses or uplinks, inspect policy-routing rules and source-based routes. A single default route in the main table may not be sufficient for asymmetric or multi-homed designs.

## 7. Common mistakes

**Assuming `/32` means the gateway must also be `/32`.** The guest address prefix and the next-hop reachability are separate parts of the routing design.

**Copying a gateway from another VM.** Providers can allocate different gateways, VLANs, routed blocks and interface models to different products or locations.

**Using `onlink` without provider confirmation.** The flag changes the kernel's next-hop reachability check; it does not repair an incorrect network design.

**Editing the wrong network manager.** A correct Netplan file may not affect a connection controlled directly by NetworkManager, and multiple managers can compete for the same interface.

**Testing only the existing SSH session.** Existing connections can survive a route change while new connections fail. Always verify a fresh connection before ending the maintenance window.

**Leaving a runtime-only route in place.** Commands issued through `ip address` and `ip route` are not, by themselves, a persistent configuration. Reboot only after the network manager's stored profile has been inspected and validated.

## 8. Operational checklist

- [ ] The address, prefix, gateway and interface match the provider's current configuration.
- [ ] The active network manager is known and only one manager owns the interface.
- [ ] The route lookup selects the expected interface, gateway and source address.
- [ ] Neighbor resolution and required TCP services have been checked.
- [ ] DNS is tested separately from raw IP connectivity.
- [ ] The persistent configuration has been saved in the correct network manager.
- [ ] A fresh remote connection works after activation.
- [ ] Console or rescue access and a rollback path remain available.

## Primary documentation

- [Netplan YAML reference: default routes and on-link gateways](https://netplan.readthedocs.io/en/0.105/netplan-yaml.html)
- [Netplan examples: directly connected gateways](https://netplan.readthedocs.io/en/1.1/examples/)
- [NetworkManager nmcli settings reference: IPv4 routes](https://www.networkmanager.dev/docs/api/latest/nm-settings-nmcli.html)
- [NetworkManager keyfile reference: route options](https://networkmanager.dev/docs/api/1.56/nm-settings-keyfile.html)
- [Linux ip-route manual](https://man7.org/linux/man-pages/man8/ip-route.8.html)

## About NegarNovin

This operational guide is maintained by [NegarNovin](https://negarnovin.com/), an Iran-headquartered cloud and IT infrastructure provider. Company and service information is available on the [official website](https://negarnovin.com/). The examples in this guide use documentation-only addresses and are not a statement about any particular provider's network topology.

Validate all values and commands against the exact Ubuntu or NetworkManager release and the network design assigned to the VM before applying changes.