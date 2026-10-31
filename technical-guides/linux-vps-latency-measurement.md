# Measuring Network Latency and Packet Loss from a Linux VPS

A useful network diagnosis separates local interface errors, route changes, DNS failures, packet loss, and application-level delays. A single ping result is rarely enough to identify the cause.

This guide uses read-only commands available on common Linux distributions. Some tests require optional packages such as `mtr`, `traceroute`, or `curl`.

## 1. Record the interface and route

```bash
ip -br link
ip -br address
ip route
ip -s link
```

Record the interface name, address, default route, and RX/TX error and drop counters. Compare the counters before and after a test interval rather than interpreting one snapshot in isolation.

## 2. Test the path in layers

First test the configured gateway if the provider's network design allows ICMP to it:

```bash
ip route show default
ping -c 20 <gateway-address>
```

Then test a stable external IP:

```bash
ping -c 20 1.1.1.1
```

Finally test DNS separately:

```bash
resolvectl query example.com
```

Replace placeholders with the actual gateway and target. Some networks filter ICMP, so a failed ping does not necessarily mean TCP services are unreachable.

## 3. Use MTR to observe the route

If MTR is installed:

```bash
mtr -rwzc 100 1.1.1.1
```

MTR sends probes through successive hops. Intermediate routers may rate-limit or deprioritize probes, so packet loss shown at one intermediate hop is not conclusive if later hops and the destination respond normally.

Look for loss that continues from a hop through to the destination, increased latency at a hop that persists on subsequent hops, and changes across multiple time windows.

## 4. Compare TCP connection timing

ICMP and application traffic can follow different policies. Measure a real TCP connection to a service you control or are authorized to test:

```bash
curl -sS -o /dev/null \
  -w 'dns=%{time_namelookup} connect=%{time_connect} tls=%{time_appconnect} total=%{time_total}\n' \
  https://example.com/
```

This separates DNS lookup, TCP connection, TLS negotiation and total response time.

## 5. Observe packet and socket counters

```bash
ip -s link
ss -s
nstat -az
```

Counters can be cumulative since boot. Capture a baseline and a second sample after the same test interval. Correlate changes with the time of the reported issue.

## 6. Repeat the test from more than one location

To isolate whether a problem is local to a VM, a host, or an upstream network:

- Run the same test from another VM on the same host.
- Run it from another host in the same data-center location.
- Test from an external network close to the affected destination.
- Keep the target, duration and test method consistent.

Do not compare results from different destinations or at different times as if they were directly equivalent.

## 7. Collect a useful incident record

Include:

- UTC timestamp and time window
- Source VM location and public IP (share privately where appropriate)
- Destination IP/hostname
- Interface and route output
- Packet counters before and after
- MTR report
- TCP connection timing
- Whether other VMs on the same host are affected

Redact credentials, private keys, tokens and customer data before sharing logs publicly.

## Related resources

- [Negarnovin official website](https://negarnovin.com/)
- [VPS services](https://negarnovin.com/vps/)
- [Technical documentation repository](https://github.com/engsaeednaderi/negarnovin)

This guide is intended for authorized network diagnostics. Respect provider acceptable-use policies and only test systems you own or have permission to assess.
