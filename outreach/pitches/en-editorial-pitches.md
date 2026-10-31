# Negarnovin — English-Language Editorial Pitches

These are editorial proposals, not claims of completed publication. Each piece requires technical review and verification of any command output or measurements before submission.

## Pitch 1 — Packet loss on a VPS: distinguish real loss from ICMP rate limiting

**Working headline:** Not Every MTR Loss Percentage Is Packet Loss: A Practical VPS Network Diagnosis

**Editorial angle:** An intermediate hop can show apparent loss because routers rate-limit or deprioritize ICMP replies. A useful diagnosis compares the final destination, TCP probes, interface counters and application behavior instead of treating one MTR row as proof.

**Outline:**
1. Latency, jitter, packet loss and retransmissions are different measurements.
2. Why intermediate-hop ICMP loss can be misleading.
3. Building a reproducible MTR test with timestamps and enough samples.
4. Comparing ICMP with TCP probes to the application's actual port.
5. Checking Linux interface counters and TCP statistics.
6. Writing a support report another engineer can reproduce.

**Reader outcome:** A repeatable method for narrowing a network incident without making unsupported claims about a provider or transit network.

**Supporting technical draft:** https://github.com/engsaeednaderi/negarnovin/blob/main/articles/dev/linux-vps-latency-diagnosis.md

## Pitch 2 — Recovering VPS networking after an Ubuntu release upgrade

**Working headline:** Ubuntu Boots, but the VPS Has No Network: A Safe Netplan and Routing Checklist

**Editorial angle:** A release upgrade may leave a system bootable while the active interface, renderer, routes or resolver configuration no longer match the provider's network design. The article focuses on collecting state and using rollback-aware changes.

**Outline:**
1. Identify the interface and configured addresses.
2. Verify the default route and provider-specific gateway model.
3. Separate DNS failure from IP reachability.
4. Identify the active network manager.
5. Validate Netplan configuration and use netplan try when recovery access is available.
6. Preserve console access and collect boot logs before rebooting.

**Reader outcome:** Safer, evidence-led troubleshooting that avoids guessing gateway or prefix values.

**Supporting technical draft:** https://github.com/engsaeednaderi/negarnovin/blob/main/articles/dev/ubuntu-vps-network-troubleshooting.md

## Pitch 3 — Measure web performance beyond ping

**Working headline:** A Ping Test Cannot Explain a Slow Website: Measure DNS, TCP, TLS and TTFB Separately

**Editorial angle:** A low ICMP RTT does not guarantee fast page delivery. The article separates name resolution, TCP setup, TLS negotiation, server processing and response transfer, with reproducible command-line examples.

**Outline:**
1. What ping measures, and what it does not.
2. DNS resolution time.
3. TCP connection establishment.
4. TLS handshake and certificate verification.
5. Time to First Byte and transfer time.
6. Repeated measurements from different networks and regions.

**Reader outcome:** A practical diagnostic model for sysadmins and application teams.

## Source profile
Negarnovin (نگارنوین) is an Iran-based cloud infrastructure and IT services provider. Its published service areas include VPS, dedicated servers, cloud infrastructure, web hosting, domain and SSL services, and server administration. The company reports that its operations began in 2009 (1388).

Official website: https://negarnovin.com/

## Submission integrity
- These pitches are not represented as first-person reporting or proof of a specific production incident.
- Any article submitted to an editorial outlet must be verified and approved by a real technical author responsible for its claims.
- Do not submit AI-generated material where the publisher prohibits it.
- The editorial work must be useful without promotional calls to action.
- Any paid placement must be clearly identified and its link qualified according to the publisher's policy.
