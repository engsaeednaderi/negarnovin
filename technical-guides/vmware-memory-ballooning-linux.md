# Understanding VMware Memory Ballooning in Linux Virtual Machines

VMware ESXi uses memory reclamation mechanisms when a host is under memory pressure. One of these mechanisms is the balloon driver, commonly referred to as `vmmemctl`. The driver cooperates with the guest operating system so that the hypervisor can reclaim memory pages and make them available to other virtual machines.

A non-zero balloon value is a diagnostic signal, not by itself proof that the guest is malfunctioning. Interpret it alongside active memory, swapping, host memory pressure, guest free memory, and workload behaviour.

## 1. Check memory from inside the Linux guest

Start with read-only commands:

```bash
free -h
grep -E 'MemTotal|MemFree|MemAvailable|SwapTotal|SwapFree|Cached|SReclaimable' /proc/meminfo
vmstat 1 5
```

Pay attention to `MemAvailable`, swap-in/swap-out activity (`si` and `so` in `vmstat`), and whether memory pressure correlates with application latency.

Linux uses otherwise idle memory for filesystem cache. A high "used" value in `free` is not enough to conclude that an application is short of memory. Check `available` and actual swapping.

## 2. Query VMware Tools from the guest

If VMware Tools or open-vm-tools is installed and the command is available, check the balloon statistic:

```bash
vmware-toolbox-cmd stat balloon
```

A value above zero indicates that the guest balloon driver is holding pages on behalf of the hypervisor. Capture the value over time; a single reading does not show whether the condition is persistent.

Check VMware Tools status:

```bash
systemctl status vmtoolsd --no-pager
vmware-toolbox-cmd -v
```

Some distributions or Tools versions expose different subcommands. Confirm command availability on the installed version.

## 3. Check the ESXi host

On the ESXi host, use `esxtop` and open the memory view. Relevant counters include:

- `MCTLSZ`: current balloon size.
- `MCTLTGT`: target balloon size.
- `SWCUR`: current swap usage.
- `SWR/s` and `SWW/s`: swap read/write rates.
- Active and consumed memory metrics.

Interpret the counters together. Sustained ballooning accompanied by host swapping is more concerning than an isolated non-zero balloon reading.

Broadcom documentation:
- [Disable Memory ballooning in a VM](https://knowledge.broadcom.com/external/article/408718/disable-memory-ballooning-in-a-vm.html)
- [How to identify Virtual Machines experiencing memory ballooning](https://knowledge.broadcom.com/external/article/429651/)
- [Troubleshooting high memory usage on Linux-based virtual machines](https://knowledge.broadcom.com/external/article/440616/high-memory-usage-on-linux-based-virtual.html)

## 4. Investigate host-side causes before changing the guest

Review:

1. Host and cluster memory demand versus physical capacity.
2. VM memory reservations, limits and resource-pool settings.
3. Other VMs on the same host and recent workload changes.
4. Balloon and swap trends in vCenter or `esxtop`.
5. Guest application memory demand and Linux swap activity.

A memory limit can create artificial memory pressure even when the host appears to have free capacity. Verify configured limits and reservations rather than assuming the VM can use all provisioned memory.

## 5. Avoid reflexively disabling the balloon driver

Disabling ballooning or reserving all guest memory changes host resource management and may reduce consolidation capacity. Broadcom describes disabling ballooning as a case-by-case action. Consider it only after reviewing host capacity, VM criticality, reservation policy and workload measurements.

Do not blacklist `vmw_balloon`, change memory reservations, or alter hypervisor settings as a generic first response.

## 6. Record evidence before and after a change

For each observation, record:

- Timestamp and VM name
- Provisioned memory and reservation/limit
- `vmware-toolbox-cmd stat balloon` output
- `free -h` and `vmstat 1 5` output
- ESXi balloon and swap counters
- Application latency or service impact

This makes it possible to distinguish a real guest memory shortage from host-level reclamation or Linux cache accounting.

## Related resources

- [Negarnovin official website](https://negarnovin.com/)
- [Negarnovin infrastructure services](https://negarnovin.com/vps/)
- [Negarnovin GitHub technical guides](https://github.com/engsaeednaderi/negarnovin/tree/main/technical-guides)

This guide is general operational information. Validate steps against the exact ESXi, VMware Tools and guest Linux versions before making production changes.
