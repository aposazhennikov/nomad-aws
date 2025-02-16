#!/bin/bash

# Update and install necessary packages
apt-get -y update
apt-get -y install software-properties-common dnsutils ca-certificates curl jq gpg net-tools expect

# Create and configure users
useradd -m -s /bin/bash -G sudo ansible
mkdir -p /home/ansible/.ssh
mkdir -p /home/admin/.ssh

# Add SSH keys
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIInRjlhOxnQvXCG68MKXArIdM5NLY7otxUtnjtquP9jH aposa@DESKTOP-6DCJQO1" | tee -a /home/admin/.ssh/authorized_keys
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIuZg5NHgUGHa9iyMv8TMDwo0ZkL9B0fU0HJG/BjijZJ ansible" | tee -a /home/ansible/.ssh/authorized_keys

# Set permissions for SSH keys
chown admin:admin /home/admin/.ssh/authorized_keys
chmod 600 /home/admin/.ssh/authorized_keys
chown ansible:ansible /home/ansible/.ssh/authorized_keys
chmod 600 /home/ansible/.ssh/authorized_keys

# Configure sudoers
echo "admin ALL=(ALL) NOPASSWD:ALL" | tee /etc/sudoers.d/admin
echo "ansible ALL=(ALL) NOPASSWD:ALL" | tee /etc/sudoers.d/ansible
chmod 440 /etc/sudoers.d/admin
chmod 440 /etc/sudoers.d/ansible

# Install Docker
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker.gpg] https://download.docker.com/linux/debian \
$(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list >/dev/null
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Create the /app/redis directory
mkdir -p /app/redis

# Create the docker-compose.yml file
cat <<EOF > /app/redis/docker-compose.yml
version: '3.8'

services:
  redisinsight:
    image: redislabs/redisinsight:latest
    container_name: redisinsight
    network_mode: 'host'
  redis-stack:
    image: redis/redis-stack-server:latest
    container_name: redis-stack
    volumes:
      - /app/redis/redis.conf:/usr/local/etc/redis/redis.conf
      - /app/redis/redis.log:/var/log/redis.log
      - /app/redis/dump:/var/lib/redis/6370
    command: ['redis-server', '/usr/local/etc/redis/redis.conf']
    network_mode: 'host'
    restart: always
volumes:
  redis-data:
EOF

# Create the redis.conf file
cat <<EOF > /app/redis/redis.conf
protected-mode no

# Network part:
bind 0.0.0.0
port 7000
timeout 0
tcp-keepalive 300
tcp-backlog 2048
maxclients 10000

# PID part:
daemonize no
supervised no
pidfile /var/run/redis.pid
set-proc-title yes
proc-title-template '{title} {listen-addr} {server-mode}'

# Log part:
loglevel notice
logfile /var/log/redis.log
slowlog-log-slower-than 10000
slowlog-max-len 1024
always-show-logo yes
locale-collate ''
latency-monitor-threshold 100
notify-keyspace-events ''

# Backup part:
save 900 1
save 300 10
save 60 10000
stop-writes-on-bgsave-error yes
rdbcompression yes
rdbchecksum yes
rdb-del-sync-files no
rdb-save-incremental-fsync yes
dbfilename dump.rdb
dir /var/lib/redis/6370
appendonly yes
appendfilename 'appendonly.aof'
appendfsync everysec
no-appendfsync-on-rewrite no
aof-load-truncated yes
aof-use-rdb-preamble yes
aof-timestamp-enabled no
aof-rewrite-incremental-fsync yes
cluster-enabled yes
cluster-node-timeout 15000
databases 16
slave-read-only yes
replica-serve-stale-data yes
repl-diskless-sync yes
repl-diskless-sync-delay 5
repl-disable-tcp-nodelay no
repl-diskless-sync-max-replicas 0
repl-diskless-load disabled
lazyfree-lazy-eviction no
lazyfree-lazy-expire no
lazyfree-lazy-server-del no
replica-lazy-flush no
lazyfree-lazy-user-del no
lazyfree-lazy-user-flush no
activerehashing yes
disable-thp yes
dynamic-hz yes
jemalloc-bg-thread yes
hash-max-listpack-entries 512
hash-max-listpack-value 64
list-max-listpack-size -2
list-compress-depth 0
set-max-intset-entries 512
set-max-listpack-entries 128
set-max-listpack-value 64
zset-max-listpack-entries 128
zset-max-listpack-value 64
hll-sparse-max-bytes 3000
stream-node-max-bytes 4096
stream-node-max-entries 100
client-output-buffer-limit normal 0 0 0
client-output-buffer-limit replica 256mb 64mb 60
client-output-buffer-limit pubsub 32mb 8mb 60
EOF
