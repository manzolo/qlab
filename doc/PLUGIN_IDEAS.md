# Plugin Ideas

Future plugin labs to implement for QLab. Grouped by topic area.

## Networking

| Plugin | Description |
|--------|-------------|
| `loadbalancer-lab` | HAProxy/Nginx as reverse proxy with 2+ backends |
| `vlan-lab` | VLAN tagging with bridge and trunk between VMs |
| `nat-lab` | NAT/masquerading and port forwarding with iptables |

## System Services

| Plugin | Description |
|--------|-------------|
| `proxy-lab` | Squid as HTTP/HTTPS proxy with ACLs |

## Storage & Filesystem

| Plugin | Description |
|--------|-------------|
| `backup-lab` | Backup strategies with rsync, tar, scheduled cron jobs |
| `iscsi-lab` | iSCSI target + initiator between 2 VMs |
| `zfs-lab` | ZFS pool, snapshots, send/receive |

## Security

| Plugin | Description |
|--------|-------------|
| `selinux-lab` | SELinux: policies, contexts, troubleshooting with audit2why |
| `ids-lab` | Intrusion detection with Snort or Suricata |
| `certssl-lab` | Minimal PKI: local CA, certificates, mutual TLS |

## Containers & Automation

| Plugin | Description |
|--------|-------------|
| `ansible-lab` | Ansible: control node + 2 managed nodes, playbook |
| `cron-lab` | Task scheduling with cron/systemd timers |

## Databases

| Plugin | Description |
|--------|-------------|
| `postgres-lab` | PostgreSQL: roles, schemas, pg_dump, streaming replication |
| `redis-lab` | Redis: data types, persistence, sentinel replication |

## Monitoring & Logging

| Plugin | Description |
|--------|-------------|
| `monitoring-lab` | Prometheus + node_exporter + Grafana |
| `logging-lab` | Centralized rsyslog or minimal ELK stack |
| `snmp-lab` | SNMP agent/manager, MIB, walk, trap |

## Advanced (multi-VM)

| Plugin | Description |
|--------|-------------|
| `cluster-lab` | HA cluster with Pacemaker/Corosync, failover |
| `k8s-lab` | Minimal Kubernetes: 1 control plane + 1 worker (k3s) |
| `pxe-lab` | PXE boot: TFTP + DHCP, network install |

## Implementation Priority

**Easy to implement** (single VM, similar pattern to nginx-lab):
postgres-lab, redis-lab, cron-lab

**Most interesting for learning** (multi-VM, more complex):
ansible-lab, k8s-lab, cluster-lab
