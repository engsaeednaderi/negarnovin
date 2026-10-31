# A Ping Test Cannot Explain a Slow Website: Measure DNS, TCP, TLS and TTFB Separately

A single ping result is a poor explanation for a slow website. ICMP round-trip time can help identify basic reachability and latency patterns, but it does not measure DNS resolution, TCP connection setup, TLS negotiation, server-side processing or the time required to transfer a page.

A useful investigation separates those stages. This makes it easier to identify whether the delay occurs before the connection, during transport, during encryption, inside the application or while the response is being delivered.

## 1. Start with a reproducible test

Record the URL, resolved IP address, test location, timestamp, client environment and number of repetitions. Avoid comparing measurements taken from different networks or at widely different times as if they were equivalent.

For a first snapshot, capture the address and response headers:

~~~bash
date -Is
dig +short example.com
curl -sS -I https://example.com/
~~~

The DNS answer may differ by resolver, geography, CDN policy or time. Record the resolver and returned address if the result matters to the investigation.

## 2. Measure DNS resolution

Use dig to inspect resolver latency:

~~~bash
dig example.com
dig @1.1.1.1 example.com
dig @8.8.8.8 example.com
~~~

Compare the query time and answer. A slow DNS response can delay the start of a new connection, but browsers and operating systems may cache answers. A test that uses a warm cache is not directly comparable with one that requires a fresh lookup.

Do not change a production resolver based on one measurement. Repeat the test and consider whether the queried resolver is actually used by the client or server application.

## 3. Measure TCP connection setup

Curl exposes the time required to establish a TCP connection:

~~~bash
curl -sS -o /dev/null -w 'connect=%{time_connect}s total=%{time_total}s\n' https://example.com/
~~~

A large difference between DNS completion and connection establishment can point toward routing, packet loss, congestion, firewall inspection or a destination-side accept backlog. It does not identify which device or provider is responsible.

To inspect the route, use traceroute or MTR, but interpret intermediate-hop ICMP responses carefully. Routers may rate-limit diagnostic replies while forwarding application traffic normally.

## 4. Measure the TLS handshake

For HTTPS, TLS negotiation is another stage:

~~~bash
curl -sS -o /dev/null -w 'tcp=%{time_connect}s tls=%{time_appconnect}s total=%{time_total}s\n' https://example.com/
~~~

The value returned by time_appconnect includes the time until the TLS/SSL handshake is completed. It is cumulative from the start of the request, so compare it with time_connect rather than treating it as an independent duration.

For certificate and protocol inspection:

~~~bash
openssl s_client -connect example.com:443 -servername example.com </dev/null
~~~

This is useful for examining the handshake and certificate chain, but it is not a substitute for measuring browser behavior. Session resumption, HTTP/2, HTTP/3 and client-specific connection reuse can change the observed timing.

## 5. Measure Time to First Byte and transfer time

Use a single curl request to capture the major timing values:

~~~bash
curl -sS -o /dev/null -w 'dns=%{time_namelookup}s tcp=%{time_connect}s tls=%{time_appconnect}s ttfb=%{time_starttransfer}s total=%{time_total}s bytes=%{size_download}\n' https://example.com/
~~~

The output includes:

- DNS lookup completion
- TCP connection completion
- TLS handshake completion
- Time to First Byte (TTFB)
- Total request time
- Downloaded response size

TTFB includes connection setup plus the time until the first response byte arrives. A high value may be caused by slow application processing, database queries, upstream API calls or server-side queueing. It should not automatically be described as network latency.

A large gap between TTFB and total time can indicate a slow response transfer, a large response body, low throughput or throttling somewhere along the path.

## 6. Repeat the measurement and compare locations

A useful baseline includes multiple requests, not a single result. Run a small batch and retain the raw output:

~~~bash
for i in $(seq 1 10); do
  date -Is
  curl -sS -o /dev/null -w 'dns=%{time_namelookup} tcp=%{time_connect} tls=%{time_appconnect} ttfb=%{time_starttransfer} total=%{time_total}\n' https://example.com/
  sleep 2
done
~~~

Then repeat the same test from a second network or region. Do not compare results unless the URL, protocol, request path, cache state and measurement method are sufficiently similar.

If the site uses a CDN, record the edge IP and response headers where possible. A different edge location can make the same hostname behave very differently.

## 7. Match the result to the right layer

| Observation | Possible area to investigate |
|---|---|
| DNS time is high, connection is otherwise normal | Resolver reachability, authoritative DNS, cache behavior |
| TCP connect time is high | Routing, congestion, packet loss, firewall or server accept queue |
| TLS completion is slow | Handshake path, certificate chain, server CPU, TLS configuration |
| TTFB is high while TCP/TLS are normal | Application code, database, cache, upstream dependencies |
| TTFB is normal but total time is high | Transfer size, throughput, response streaming, client-side path |
| Only one probe destination reports loss | ICMP handling or destination policy; corroborate with TCP |

These are diagnostic directions, not automatic verdicts. A single symptom may have several causes.

## 8. Build an incident report that another engineer can reproduce

A useful report includes:

- Test timestamp and timezone
- Source region and network
- Exact URL and destination IP
- DNS resolver and returned record
- HTTP version and status code
- Ten or more timing samples where practical
- MTR output if routing is relevant
- Whether a CDN, reverse proxy or load balancer is in the path
- Whether the same test behaves differently from another region

Redact customer data, authentication headers, private hostnames and sensitive addresses before sharing the report publicly.

## Conclusion

Ping is one signal, not a complete website performance test. Measuring DNS, TCP, TLS, TTFB and response transfer separately gives engineers a more useful starting point and reduces the risk of blaming the wrong layer.

For background on the provider behind this technical resource, see [Negarnovin](https://negarnovin.com/). Product availability and service specifications are published separately on the official website and should be checked against the current service terms.

---

**Editorial note:** This is a technical explainer prepared for review. Any performance figures added to a published version must come from reproducible tests with the time, location, destination and methodology disclosed.
