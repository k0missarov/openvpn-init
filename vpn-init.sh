#!/bin/bash
echo -n "Amount of keys will be created:"
read keynum
echo -n "Email address to which the keys will be sent:"
read mailto

apt-get update
apt-get install -y openvpn easy-rsa
apt-get install -y ufw
apt-get install -y mutt
apt-get install -y zip

make-cadir /root/openvpn-ca

cd /root/openvpn-ca

##change vars

sed -i.bak -r 's/export KEY_NAME="EasyRSA"/export KEY_NAME="server"/g' /root/openvpn-ca/vars

source vars
./clean-all
./build-ca --batch
./build-key-server --batch server
./build-dh
openvpn --genkey --secret keys/ta.key

##cd ~/openvpn-ca
##source vars

for ((i=1; i<$keynum; i++))
do
./build-key --batch 'client'${i}
done

##cd ~/openvpn-ca/keys

cp /root/openvpn-ca/keys/ca.crt /etc/openvpn
cp /root/openvpn-ca/keys/server.crt /etc/openvpn
cp /root/openvpn-ca/keys/server.key /etc/openvpn
cp /root/openvpn-ca/keys/ta.key /etc/openvpn
cp /root/openvpn-ca/keys/dh2048.pem /etc/openvpn

## ca.key server.crt server.key ta.key dh2048.pem /etc/openvpn

gunzip -c /usr/share/doc/openvpn/examples/sample-config-files/server.conf.gz | sudo tee /etc/openvpn/server.conf

echo 'key-direction 0' >> /etc/openvpn/server.conf
echo 'auth SHA256' >> /etc/openvpn/server.conf

sed -i.bak -r 's/;tls-auth ta.key/tls-auth ta.key/g' /etc/openvpn/server.conf
sed -i.bak -r 's/;cipher AES-128-CBC/cipher AES-128-CBC/g' /etc/openvpn/server.conf
sed -i.bak -r 's/;user nobody/user nobody/g' /etc/openvpn/server.conf
sed -i.bak -r 's/;group nogroup/group nogroup/g' /etc/openvpn/server.conf
sed -i.bak -r 's/;push "dhcp-option DNS 208.67.222.222"/push "dhcp-option DNS 208.67.222.222"/g' /etc/openvpn/server.conf
sed -i.bak -r 's/;push "dhcp-option DNS 208.67.220.220"/push "dhcp-option DNS 208.67.220.220"/g' /etc/openvpn/server.conf
sed -i.bak -r 's/;push "redirect-gateway def1 bypass-dhcp"/push "redirect-gateway def1 bypass-dhcp"/g' /etc/openvpn/server.conf


sed -i.bak -r 's/#{1,}?net.ipv4.ip_forward ?= ?(0|1)/net.ipv4.ip_forward = 1/g' /etc/sysctl.conf

sysctl -p
int=$(ip route | grep default | sed 's|.*dev ||' | sed -r 's/ .+//')
##echo $int

sed -i '1s/^/# START OPENVPN RULES\n/' /etc/ufw/before.rules
sed -i '2s/^/# NAT table rules\n/' /etc/ufw/before.rules
sed -i '3s/^/*nat\n/' /etc/ufw/before.rules
sed -i '4s/^/:POSTROUTING ACCEPT [0:0]\n/' /etc/ufw/before.rules
sed -i '5s/^/# Allow traffic from OpenVPN client to '$int'\n/' /etc/ufw/before.rules
sed -i '6s/^/-A POSTROUTING -s 10.8.0.0\/8 -o '$int' -j MASQUERADE\n/' /etc/ufw/before.rules
sed -i '7s/^/COMMIT\n/' /etc/ufw/before.rules
sed -i '8s/^/# END OPENVPN RULES\n/' /etc/ufw/before.rules

sed -i.bak -r 's/DEFAULT_FORWARD_POLICY="DROP"/DEFAULT_FORWARD_POLICY="ACCEPT"/g' /etc/default/ufw
ufw allow 1194/udp
ufw allow OpenSSH
ufw disable
ufw --force enable
systemctl start openvpn@server
systemctl enable openvpn@server
mkdir -p /root/client-configs/files
chmod 700 /root/client-configs/files
cp /usr/share/doc/openvpn/examples/sample-config-files/client.conf /root/client-configs/base.conf

ipaddr=$(ip route get 8.8.8.8 | awk 'NR==1 {print $NF}')
#$echo $ipaddr

sed -i.bak -r "s/my-server-1/$ipaddr/g" /root/client-configs/base.conf

sed -i.bak -r 's/ca ca.crt/#ca ca.crt/g' /root/client-configs/base.conf
sed -i.bak -r 's/cert client.crt/#cert client.crt/g' /root/client-configs/base.conf
sed -i.bak -r 's/key client.key/#key client.key/g' /root/client-configs/base.conf
echo 'cipher AES-128-CBC' >> /root/client-configs/base.conf 
echo 'auth SHA256' >> /root/client-configs/base.conf
echo 'key-direction 1' >> /root/client-configs/base.conf

#######################
##echo '#!/bin/bash' >> ~/client-configs/make_config.sh
##echo '# First argument: Client identifier' >> ~/client-configs/make_config.sh
##echo 'KEY_DIR=~/openvpn-ca/keys' >> ~/client-configs/make_config.sh
##echo 'OUTPUT_DIR=~/client-configs/files' >> ~/client-configs/make_config.sh
##echo 'BASE_CONFIG=~/client-configs/base.conf' >> ~/client-configs/make_config.sh
##echo 'cat ${BASE_CONFIG} <(echo -e \'<ca>\') ${KEY_DIR}/ca.crt <(echo -e \'</ca>\n<cert>\') \'${KEY_DIR}/${1}.crt <(echo -e \'</cert>\n<key>\') ${KEY_DIR}/${1}.key <(echo -e \'</key>\n<tls-auth>\') ${KEY_DIR}/ta.key <(echo -e \'</tls-auth>\') > ${OUTPUT_DIR}/${1}.ovpn' >> ~/client-configs/make_config.sh
#######################


#chmod 700 ~/client-configs/make_config.sh


for ((i=1; i <$keynum; i++))
do
/root/client-configs/make_config.sh 'client'${i}
done



#/root/client-configs/make_config.sh client3



zip -r /root/client-configs/keys.zip /root/client-configs/files/

host=$(hostname)

echo "OpenVPN keys for $host ($ipaddr)" | mutt -a "/root/client-configs/keys.zip" -s "OpenVPN keys" -- $mailto
