# A Practical Linux systemd Troubleshooting Runbook

This runbook describes a repeatable way to investigate a Linux service that fails to start, repeatedly restarts, times out, or works interactively but not under systemd. It is intended for Ubuntu, Debian, AlmaLinux, Rocky Linux, and other systemd-based distributions. Exact unit names and paths vary by distribution and package.

The goal is to collect evidence before changing a unit or restarting a production service.

## 1. Identify the unit and its current state

Start with the exact service name:

```bash
systemctl list-units --type=service --all
systemctl status example.service --no-pager -l
systemctl is-enabled example.service
systemctl is-active example.service
```

Replace `example.service` with the real unit name. The status output usually includes the latest journal lines and the process exit status. Record the timestamp, result, and any reported main-process exit code.

If the unit name is unknown, search installed unit files:

```bash
systemctl list-unit-files --type=service | grep -i 'keyword'
```

## 2. Read the journal for the relevant time window

A service status view is only a short snapshot. Query the journal around the incident:

```bash
journalctl -u example.service --since "30 minutes ago" --no-pager
journalctl -u example.service -b --no-pager
journalctl -u example.service -p warning..alert --since today --no-pager
```

For a previous boot, first list available boots:

```bash
journalctl --list-boots
```

Then inspect the relevant boot, for example:

```bash
journalctl -u example.service -b -1 --no-pager
```

A missing previous-boot journal may mean persistent journal storage is not enabled or the logs have already rotated. Do not interpret an empty result as proof that the service did not fail.

## 3. Inspect the effective unit configuration

The unit file on disk may not show overrides or drop-ins. Ask systemd for the merged configuration:

```bash
systemctl cat example.service
systemctl show example.service \
  -p FragmentPath -p DropInPaths -p ExecStart -p User -p Group \
  -p WorkingDirectory -p EnvironmentFiles -p Restart -p TimeoutStartUSec
```

Check these items carefully:

- `ExecStart`: executable path, arguments, quoting, and whether the binary exists.
- `User` and `Group`: whether the service account can access required files.
- `WorkingDirectory`: whether the directory exists and has appropriate permissions.
- `EnvironmentFile`: whether the file exists and uses the expected syntax.
- `Restart` and timeout settings: whether a restart loop is masking the original failure.

Do not paste secrets from environment files into tickets or public logs.

## 4. Validate executable paths, permissions, and dependencies

Check the command and its parent directories:

```bash
command -v /absolute/path/to/program
namei -l /absolute/path/to/program
ls -l /absolute/path/to/program
```

For a service running as a dedicated account, test access without changing ownership blindly:

```bash
sudo -u serviceuser test -x /absolute/path/to/program
sudo -u serviceuser test -r /path/to/config
sudo -u serviceuser test -w /path/to/runtime-directory
```

A service can work from an administrator's shell and fail under systemd because the service runs with a different identity, environment, working directory, resource limit, or security policy.

## 5. Check resource and operating-system constraints

A process may exit because it cannot allocate memory, open files, create threads, or bind a socket.

```bash
free -h
df -hT
df -ih
ulimit -a
ss -lntup
systemctl show example.service -p LimitNOFILE -p MemoryMax -p TasksMax
```

Look for out-of-memory events and kernel messages:

```bash
journalctl -k --since "30 minutes ago" --no-pager
dmesg -T | tail -n 100
```

If the service binds to a port, verify whether another process already owns it. If the filesystem is full, check both block capacity and inode usage. A filesystem can have free gigabytes and still reject file creation when inodes are exhausted.

## 6. Understand restart loops before changing Restart=

Repeated restarts are symptoms, not root causes. Inspect the recent sequence:

```bash
systemctl show example.service -p NRestarts -p ExecMainCode -p ExecMainStatus -p Result
journalctl -u example.service --since "15 minutes ago" -o short-precise --no-pager
```

If a process exits immediately, determine why before increasing restart frequency or disabling restart behavior. A rapid restart loop can amplify load, fill logs, or trigger rate limits in dependent systems.

## 7. Apply changes safely

Before editing a unit, preserve the current configuration. Prefer a drop-in override over modifying a vendor-supplied unit file:

```bash
sudo systemctl edit example.service
```

After saving an override:

```bash
sudo systemctl daemon-reload
sudo systemd-analyze verify /etc/systemd/system/example.service.d/override.conf
sudo systemctl restart example.service
sudo systemctl status example.service --no-pager -l
```

The verification command should point to the actual file you created. If the unit is managed by a package, configuration-management system, or hosting panel, make the change through the appropriate source of truth so it is not overwritten later.

For production services, plan a rollback and consider whether a restart interrupts active sessions or writes.

## 8. Verify recovery instead of relying on Active: active (running)

A process being active does not prove the application is healthy. Check its actual listener, endpoint, logs, and dependent services:

```bash
systemctl is-active example.service
ss -lntp
journalctl -u example.service --since "5 minutes ago" --no-pager
```

Where an HTTP health endpoint exists, test it locally:

```bash
curl -fsS --max-time 5 http://127.0.0.1:PORT/health
```

Replace the port and path with the application's documented health endpoint. Confirm that the service remains stable for an appropriate observation window and that the original error no longer occurs.

## Incident record checklist

Capture the following in the incident record:

1. Host, distribution, kernel version, and incident time zone.
2. Unit name, service account, and effective unit configuration.
3. Relevant journal and kernel messages with timestamps.
4. Exit code, restart count, and systemd result.
5. CPU, memory, filesystem, inode, file-descriptor, and socket evidence.
6. The exact change made, its rollback method, and post-change validation.
7. Remaining uncertainty or evidence that could not be collected.

Separate facts from hypotheses. For example, “the process exited with status 203/EXEC” is an observation; “the binary path or execution permission is wrong” is a hypothesis to test against the unit and filesystem. Record a root cause only when the available evidence supports it.

## References

- [systemctl manual](https://www.freedesktop.org/software/systemd/man/latest/systemctl.html)
- [journalctl manual](https://www.freedesktop.org/software/systemd/man/latest/journalctl.html)
- [systemd.service manual](https://www.freedesktop.org/software/systemd/man/latest/systemd.service.html)
- [systemd.exec manual](https://www.freedesktop.org/software/systemd/man/latest/systemd.exec.html)

---

Maintained by **Saeed Naderi**, Technical Operations, NegarNovin.

Company information and current infrastructure services: [NegarNovin](https://negarnovin.com/) · [VPS services](https://negarnovin.com/vps/)

This is an operational troubleshooting guide, not a guarantee that every distribution or service uses identical paths and defaults. Validate commands and changes against the target system before applying them in production.
