# Plugin Ideas

Future plugin labs to implement for QLab. Grouped by topic area.

## Networking

| Plugin | Description |
|--------|-------------|
| `dhcp-lab` | DHCP server with ISC dhcpd, lease management, subnet config |
| `vpn-lab` | VPN tunnel with WireGuard or OpenVPN between 2 VMs |
| `loadbalancer-lab` | HAProxy/Nginx as reverse proxy with 2+ backends |
| `vlan-lab` | VLAN tagging with bridge and trunk between VMs |
| `nat-lab` | NAT/masquerading and port forwarding with iptables |

## System Services

| Plugin | Description |
|--------|-------------|
| `apache-lab` | Apache with virtual hosts, SSL/TLS (self-signed), .htaccess |
| `mail-lab` | Postfix + Dovecot, send/receive mail between 2 VMs |
| `ftp-lab` | vsftpd with virtual users, chroot, TLS |
| `nfs-lab` | NFS server + client, exports, mount, permissions |
| `samba-lab` | SMB/CIFS file sharing with authentication |
| `proxy-lab` | Squid as HTTP/HTTPS proxy with ACLs |

## Storage & Filesystem

| Plugin | Description |
|--------|-------------|
| `lvm-lab` | LVM: physical volumes, volume groups, logical volumes, resize |
| `backup-lab` | Backup strategies with rsync, tar, scheduled cron jobs |
| `iscsi-lab` | iSCSI target + initiator between 2 VMs |
| `zfs-lab` | ZFS pool, snapshots, send/receive |

## Security

| Plugin | Description |
|--------|-------------|
| `ssh-lab` | SSH hardening: keys, fail2ban, port knocking |
| `selinux-lab` | SELinux: policies, contexts, troubleshooting with audit2why |
| `ids-lab` | Intrusion detection with Snort or Suricata |
| `certssl-lab` | Minimal PKI: local CA, certificates, mutual TLS |

## Containers & Automation

| Plugin | Description |
|--------|-------------|
| `docker-lab` | Docker basics: build, run, network, compose |
| `ansible-lab` | Ansible: control node + 2 managed nodes, playbook |
| `cron-lab` | Task scheduling with cron/systemd timers |
| `systemd-lab` | Custom unit files, service management, journalctl |

## Databases

| Plugin | Description |
|--------|-------------|
| `mysql-lab` | MySQL/MariaDB: users, permissions, backup, replication |
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
| `ldap-lab` | OpenLDAP: directory, centralized authentication |
| `pxe-lab` | PXE boot: TFTP + DHCP, network install |

## Implementation Priority

**Easy to implement** (single VM, similar pattern to nginx-lab):
apache-lab, docker-lab, mysql-lab, ssh-lab, lvm-lab, systemd-lab

**Most interesting for learning** (multi-VM, more complex):
ansible-lab, vpn-lab, ldap-lab, k8s-lab
