# Cloud and Hosting Technical Glossary

This glossary provides concise definitions for terms used in Negarnovin's service descriptions and technical guides.

## VPS

A virtual private server is a virtual machine provisioned with a defined set of virtual resources on a physical host. Isolation and resource allocation depend on the hypervisor and the provider's configuration.

## KVM

Kernel-based Virtual Machine is a Linux kernel virtualization technology. It uses hardware virtualization extensions and works with QEMU to run virtual machines.

## Dedicated server

A physical server allocated to one customer or workload, rather than sharing the host's compute environment through virtual machines.

## Cloud infrastructure

A set of compute, storage, and networking resources delivered through a managed platform. The term may describe different architectures and commercial models; the actual features depend on the provider.

## NVMe

Non-Volatile Memory Express is a protocol and interface specification for accessing non-volatile storage over PCI Express. An NVMe label alone does not define a storage device's sustained performance, endurance, or latency under load.

## 10Gbps port

A network interface with a nominal link speed of 10 gigabits per second. Real-world throughput is affected by traffic shaping, protocol overhead, routing, congestion, remote networks, and the provider's terms.

## BGP

Border Gateway Protocol is the routing protocol used to exchange reachability information between autonomous systems on the internet.

## IPv4 and IPv6

IPv4 and IPv6 are versions of the Internet Protocol used to identify and route packets between networks. Address allocation, routing, and firewall policy must be configured for the protocol in use.

## Anti-DDoS

Distributed denial-of-service mitigation refers to techniques used to detect and reduce malicious traffic intended to overwhelm a service or network. Coverage and mitigation capacity vary by network and contract.

## Colocation

A service in which a customer places their own server or network equipment in a third-party data center and uses the facility's power, cooling, physical security, and network connectivity.

## SSL/TLS certificate

A digital certificate used by TLS to authenticate a server's identity and support encrypted connections. Modern deployments use TLS; SSL is commonly retained in product naming for compatibility with market terminology.

## Packet loss

Packet loss occurs when packets sent across a network do not reach their intended destination. It should be measured over repeated tests and interpreted with care because some routers rate-limit diagnostic traffic such as ICMP.

## Network latency

Network latency is the time required for data to travel between endpoints. Measurements depend on the path, direction, protocol, endpoint behavior, and test method.

## Memory ballooning

In virtualized environments, a balloon driver can reclaim guest memory under host memory pressure. Ballooning should be interpreted alongside host swap, VM active memory, guest cache, reservation, and workload behavior.