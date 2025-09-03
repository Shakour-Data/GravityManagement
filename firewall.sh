#!/bin/bash

# GravityPM Firewall Configuration
# This script sets up basic firewall rules for the application

# Flush existing rules
iptables -F
iptables -X

# Default policies
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# Allow loopback interface
iptables -A INPUT -i lo -j ACCEPT

# Allow established connections
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Allow SSH (change port if needed)
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# Allow HTTP and HTTPS
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT

# Allow application ports
iptables -A INPUT -p tcp --dport 3000 -j ACCEPT  # Frontend (Next.js)
iptables -A INPUT -p tcp --dport 8000 -j ACCEPT  # Backend (FastAPI)

# Allow monitoring ports
iptables -A INPUT -p tcp --dport 9090 -j ACCEPT  # Prometheus
iptables -A INPUT -p tcp --dport 3000 -j ACCEPT  # Grafana (if running on different port)
iptables -A INPUT -p tcp --dport 5601 -j ACCEPT  # Kibana

# Allow database ports (restrict to specific IPs in production)
iptables -A INPUT -p tcp --dport 27017 -j ACCEPT  # MongoDB
iptables -A INPUT -p tcp --dport 6379 -j ACCEPT  # Redis

# Allow ICMP (ping)
iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT

# Log dropped packets
iptables -A INPUT -j LOG --log-prefix "IPTABLES-DROP: " --log-level 4

# Save rules (Ubuntu/Debian)
# iptables-save > /etc/iptables/rules.v4

# For CentOS/RHEL
# service iptables save

echo "Firewall rules configured successfully!"
echo "To make rules persistent, run:"
echo "Ubuntu/Debian: iptables-save > /etc/iptables/rules.v4"
echo "CentOS/RHEL: service iptables save"
