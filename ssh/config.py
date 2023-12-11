#!/usr/bin/env python3

import sys

hosts = []
addrs = []
with open("/etc/hosts", "r") as f:
    for line in f.readlines():
        line = line.strip()
        if "localhost" in line:
            continue
        addr, names = line.split()
        addrs.append(addr.strip())
        hosts.append(names.split(",")[-1].strip())

user = sys.argv[1]
ssh_config = "\n".join(f"""
Host {host}
    Hostname {addr}
    User {user}
    IdentityFile ~/.ssh/cloudlab_rsa
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
""" for host, addr in zip(hosts, addrs))

print(ssh_config)
