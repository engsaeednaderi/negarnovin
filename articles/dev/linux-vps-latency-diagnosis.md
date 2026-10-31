# Diagnosing Latency and Packet Loss on a Linux VPS

A high ping value does not automatically mean that a VPS provider has a network fault. The delay may originate on the local access network, an intermediate transit provider, the destination network, congestion, routing asymmetry, or the application itself. A useful diagnosis separates these possibilities before changing routes or opening a support ticket.

This walkthrough uses standard Linux tools and avoids destructive network changes.

## 1. Record the environment

Start with the operating-system and interface details:

~~~bash
cat /etc/os-release
ip -br address
ip route
ip -s link
~~~

Record the test time, source location, destination IP, protocol and whether the test was performed from the VPS or from a client machine. Latency is directional: a test from the server to a destination does not fully describe the route from a remote user to the server.

## 2. Check local packet errors

~~~bash
ip -s link
ethtool -S ens3 2>/dev/null | head -n 80
~~~

Replace ens3 with the actual interface. Look for increments in RX/TX errors, drops, overruns or carrier events. Some virtual NIC drivers expose only a subset of counters; an unchanged counter snapshot is not proof that every network segment is healthy.

## 3. Measure reachability to several destinations

Use more than one destination to avoid confusing a remote host's ICMP policy with a general network issue:

~~~bash
ping -c 20 1.1.1.1
ping -c 20 8.8.8.8
ping -c 20 <your-destination-ip>
~~~

Record packet loss, minimum/average/maximum RTT and the time of the test. Some networks rate-limit or deprioritize ICMP, so compare with application-level TCP tests before drawing a conclusion.

## 4. Trace the route with MTR

Install MTR if it is not already present:

~~~bash
# Debian / Ubuntu
sudo apt-get update
sudo apt-get install -y mtr-tiny

# AlmaLinux / RHEL-family systems (package availability may vary)
sudo dnf install -y mtr
~~~

Run a report:

~~~bash
mtr -rwzc 100 <destination-ip>
~~~

For TCP-oriented investigation, where supported by the installed MTR build:

~~~bash
mtr --tcp --port 443 -rwzc 100 <destination-ip>
~~~

Interpret the final destination and the pattern across hops. Packet loss shown at one intermediate router but not carried through to later hops often indicates ICMP rate limiting rather than forwarded-packet loss. Loss that continues through subsequent hops and reaches the destination is more concerning, but still needs corroboration.

## 5. Compare TCP connection timing

ICMP latency is not the same as the time required to establish an application connection. For an HTTPS endpoint:

~~~bash
curl -sS -o /dev/null \
  -w 'dns=%{time_namelookup}s connect=%{time_connect}s tls=%{time_appconnect}s ttfb=%{time_starttransfer}s total=%{time_total}s\n' \
  https://example.com/
~~~

Run several samples and compare DNS, TCP connect, TLS handshake and time-to-first-byte. A slow DNS lookup points to a different layer than a slow TCP handshake.

## 6. Inspect TCP retransmissions and socket state

~~~bash
nstat -az | grep -Ei 'Retrans|Timeout|ListenDrops'
ss -s
ss -ti
~~~

Take two snapshots separated by a measured interval. Counters are cumulative since boot, so their absolute values are less useful than the rate of increase during the incident.

## 7. Test from both directions

For a meaningful comparison, run MTR or equivalent tests from:

1. The VPS to the affected client or a stable probe endpoint.
2. The client network to the VPS public IP.
3. The VPS to multiple independent destinations.

Use TCP probes on the application's port when ICMP is filtered. Do not interpret the first visible hop as the only source of the problem; return paths may be different.

## 8. Prepare a reproducible support report

Include:

- Exact test timestamp and timezone
- Source and destination locations (mask public IPs before public posting if required)
- Destination IP and protocol/port
- MTR report with at least 100 cycles
- Ping summary from multiple targets
- TCP timing output
- Interface error-counter snapshots
- Whether the issue affects inbound, outbound, or both directions

Remove credentials, customer information and private keys from logs before sharing them.

## References

- MTR project: https://github.com/traviscross/mtr
- iproute2 documentation: https://www.kernel.org/doc/html/latest/networking/index.html
- curl write-out variables: https://curl.se/docs/manpage.html#-w
- Negarnovin technical guides: https://github.com/engsaeednaderi/negarnovin/tree/main/technical-guides

This article describes a diagnostic process, not a guarantee that a particular network path is faulty. Network conclusions should be based on repeated, time-correlated measurements from both sides of the connection.