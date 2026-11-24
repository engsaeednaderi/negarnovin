# Diagnose SSH Access Failures on Ubuntu VPS Without Rebooting

**Audience:** Linux administrators and VPS operators  
**Scope:** Ubuntu Server 22.04 LTS and 24.04 LTS  
**Purpose:** Separate client-side failures, network-path problems, firewall filtering, and SSH daemon faults before restarting services or rebooting a production server.

An SSH timeout, connection refusal, and authentication failure are different symptoms. Treating them as the same problem often leads to unnecessary restarts and loss of useful evidence. This runbook starts with the least disruptive checks and moves toward configuration changes only when the evidence supports them.

> **Safety:** Prefer the provider's web console or out-of-band console when SSH is unavailable. Do not flush firewall rules, replace network configuration, or restart networking as a first response. Keep a recovery path open before changing access controls.

## 1. Classify the client-side error

From the client machine, capture the exact error and run:

```bash
ssh -vvv -o ConnectTimeout=5 -o ConnectionAttempts=1 user@SERVER_IP
```

If the SSH port is not the default, specify it with `-p PORT`.

Typical distinctions:

- **Connection timed out:** the TCP handshake did not complete. Check the destination address, route, upstream filtering, provider firewall, guest firewall, and whether the server is reachable.
- **Connection refused:** the destination actively rejected the TCP connection. The SSH daemon may be stopped, listening on another port, or not bound to the destination address. A firewall can also reject rather than silently drop traffic.
- **Permission denied:** the TCP connection and SSH protocol negotiation reached an authentication stage. Investigate username, key selection, account state, permissions, and the server's authentication policy.
- **Host key warning:** the client sees a different host key than the one previously recorded. Verify the server identity through a trusted console or provider channel before changing the client's known-hosts entry.

A single failed ping is not proof that SSH is unavailable. ICMP may be filtered while TCP remains reachable.

## 2. Confirm the destination and route

On the client, verify that the hostname resolves to the intended address:

```bash
getent ahosts SERVER_NAME
ip route get SERVER_IP
```

If the service uses a non-standard port, test that exact port:

```bash
nc -vz -w 5 SERVER_IP PORT
```

If `nc` is not installed, use an approved TCP diagnostic tool already available on the client. Do not install packages on a production server merely to perform the first check.

Record the destination IP, port, timestamp, client public IP, and exact error. These details help distinguish a server-side issue from a source-address block or an upstream network problem.

## 3. Inspect the server from its console

Use the provider console or another trusted access path. Start with read-only checks:

```bash
date -Is
uptime
free -h
df -h
df -i
ip -br link
ip -br address
ip route
```

Look for a missing interface, an unexpected address, a missing default route, exhausted disk space, exhausted inodes, or severe resource pressure. Do not infer that the network is healthy merely because the VM is running.

Check the SSH service:

```bash
sudo systemctl status ssh --no-pager
sudo ss -lntp
```

On Ubuntu, the service unit is normally named `ssh.service`. The listening-socket output is authoritative for the ports currently bound by processes. Confirm that the daemon is listening on the expected address and port, not only that the service is marked active.

## 4. Read SSH logs before changing anything

Inspect recent service logs from the current boot:

```bash
sudo journalctl -b -u ssh --no-pager -n 200
```

If the service is not found, inspect the installed unit names:

```bash
systemctl list-unit-files | grep -Ei 'ssh|sshd'
```

Look for configuration parse errors, host-key loading errors, failed bind operations, rate limiting, account restrictions, and repeated authentication failures. Preserve the relevant time window before rotating logs or making changes.

## 5. Validate the effective SSH configuration

First test the configuration syntax:

```bash
sudo sshd -t
```

No output normally indicates that the syntax check completed without reporting an error. If it reports a file and line number, inspect that exact location before editing.

Review selected effective settings:

```bash
sudo sshd -T | grep -Ei '^(port|listenaddress|pubkeyauthentication|passwordauthentication|permitrootlogin|maxstartups)'
```

The effective configuration can depend on connection-specific `Match` rules. For a connection-specific evaluation, use `sshd -T -C` with the actual user, source address, local address, and local port. Do not enable password authentication or root login simply because a connection failed.

## 6. Check guest and provider firewalls separately

On the guest, inspect the firewall without modifying it:

```bash
sudo ufw status verbose
sudo nft list ruleset
```

If UFW is not installed or is inactive, that does not prove there is no filtering. The host may use nftables directly, iptables compatibility rules, a provider firewall, a hypervisor-level filter, or an upstream network ACL.

Check whether the expected port is allowed from the actual client source address. Avoid broad rules such as allowing SSH from every address unless that is an intentional, documented policy.

If Fail2ban is installed, inspect its state rather than disabling it:

```bash
sudo fail2ban-client status
sudo fail2ban-client status sshd
```

The second command applies only when an `sshd` jail exists. Confirm whether the client address is banned and why before taking action.

## 7. Separate guest problems from upstream filtering

Use the evidence collected so far:

| Evidence | Next area to investigate |
| --- | --- |
| SSH daemon is not active | Service logs, package state, configuration syntax |
| Daemon is active but no expected listening socket exists | `sshd_config`, bind address, port, startup logs |
| Socket listens locally but remote TCP test times out | Guest firewall, provider firewall, routing, upstream ACL |
| TCP connects but authentication fails | User account, authorized keys, file permissions, authentication policy |
| Only one client source fails | Source IP filtering, Fail2ban, upstream ACL, client route |
| Multiple services fail and the guest has no default route | Guest addressing, routes, network manager, provider network |
| Disk or inode capacity is exhausted | Identify the affected filesystem and logs before cleanup |

When available, compare the VM's guest-side observations with provider or hypervisor telemetry. A guest can show a listening socket while traffic is still blocked outside the guest.

## 8. Apply the smallest justified recovery

Only after identifying the likely cause should you make a change. Before editing:

1. Save a copy of the exact configuration file.
2. Keep the console session open.
3. Record the current firewall and SSH state.
4. Change one setting at a time.
5. Validate SSH syntax with `sshd -t` before reloading the daemon.
6. Test a second SSH session before closing the recovery session.

If the SSH configuration is valid and a reload is appropriate:

```bash
sudo systemctl reload ssh
```

A reload is not a substitute for diagnosing a network path failure. Do not restart the network stack or reboot the VM merely because SSH is unavailable; those actions can remove the remaining recovery path and erase volatile evidence.

## 9. Capture a concise incident record

For a useful incident record, save:

- Timestamp and timezone
- Client source IP, destination IP, and SSH port
- Exact client error and relevant verbose SSH lines
- Server interface, address, route, and listening sockets
- SSH service status and relevant journal entries
- Guest firewall state and any provider-side filtering findings
- The change made, its validation result, and rollback method

Redact private keys, passwords, tokens, customer identifiers, and unrelated public IP addresses before sharing diagnostic output.

## Primary references

- [Ubuntu Server documentation](https://documentation.ubuntu.com/server/)
- [OpenSSH manual pages: sshd](https://man.openbsd.org/sshd)
- [OpenSSH manual pages: sshd_config](https://man.openbsd.org/sshd_config)
- [systemd journalctl documentation](https://www.freedesktop.org/software/systemd/man/latest/journalctl.html)
- [nftables documentation](https://netfilter.org/projects/nftables/)

## About this guide

This operational guide is maintained by NegarNovin, an Iran-headquartered cloud and IT infrastructure provider established in 2009. The guide is general technical documentation, not a claim that every command has been tested on every provider network or Ubuntu image. Validate commands and access policies against the exact operating-system release and environment.

- [NegarNovin official website](https://negarnovin.com/)
- [VPS and cloud server services](https://negarnovin.com/vps/)
- [Contact and support](https://negarnovin.com/contact-us/)
