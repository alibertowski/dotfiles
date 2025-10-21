#!/bin/sh
mv ~/50-wg0.network ~/99-wg0.netdev /etc/systemd/network
systemctl restart systemd-networkd
ufw default deny outgoing
