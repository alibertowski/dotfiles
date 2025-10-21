#!/bin/sh
mv /etc/systemd/network/50-wg0.network /etc/systemd/network/99-wg0.netdev ~/
systemctl restart systemd-networkd
ufw default allow outgoing
