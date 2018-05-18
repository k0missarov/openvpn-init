#!/bin/bash
mkdir /root/client-configs/
cp /root/openvpn-init/make_config.sh /root/client-configs
chmod +x /root/client-configs/make_config.sh
chmod +x /root/openvpn-init/vpn-init.sh
/root/openvpn-init/vpn-init.sh
