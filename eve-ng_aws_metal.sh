#!/bin/sh
#At the first time:
#On the server:
#mkdir /etc/skel/.ssh
#useradd -m -G sudo,adm <username>
#chown -R <username>:adm /home/<username>/
#chmod g+w /home/<username>/.ssh
#On the client:
#ssh-keygen -b 4096 -t rsa -f <output_file>
#ssh-add <private_key>
#ssh-copy-id [-i <pem_file>.pem] root@<host>
#OR
#scp [-i <pem_file>.pem] <output_file>.pub root@<host>:/home/<username>/.ssh/authorized_keys
#chown <username>:<username> /home/<username> -R
#chmod o-rwx /home/<username> -R

#The client side
#ssh-keygen -b 4096 -t ed25519 -f <output_file>
#ssh-copy-id -i <output_file> <username>@<host>
#OR
#scp <output_file>.pub <username>@<host>:/home/<username>/.ssh

#Run all as root
#The server side optional:
#useradd -m -G sudo <username>
#passwd -e <username>
#userdel -r <username>

#The server side
apt-get update -y && \
apt-get install -y make && \
apt-get install -y wget && \
apt-get install -y gcc && \
apt-get install -y vim && \
apt-get install -y bridge-utils && \
apt-get install -y expect

#CREATING IN SKELETON FOR NEW USERS .SSH DIR
mkdir /etc/skel/.ssh

#ENABLING WHEEL
sed -i -e 's/# auth       required   pam_wheel.so/ auth       required   pam_wheel.so/' /etc/pam.d/su

#CONFIGURING ONLY PUBKEY AUTHENTICATION
sed -i -e 's/PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i -e 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i -e 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i -e 's/#AuthorizedKeysFile/AuthorizedKeysFile/' /etc/ssh/sshd_config

#ADDING GOOGLE DNS NAMESERVER
sed -i -e 's/nameserver 0.0.0.0/nameserver 8.8.8.8/' /etc/resolv.conf

#USING ETH NAMING IN GRUB
sed -i -e 's/GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="net.ifnames=0 biosdevname=0 noquiet"/' /etc/default/grub
update-grub

sed -i -e 's/NAME=.*/NAME="eth0"/' /etc/udev/rules.d/70-persistent-net.rules
mv /lib/udev/rules.d/80-net-setup-link.rules /lib/udev/rules.d/80-net-setup-link.rules.old

#SET UP SCRIPT FOR INTERFACES
cat > /etc/eve-ng-interface-tuning.sh << EOF
#!/bin/sh
cat > /etc/network/interfaces << EOF
# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
auto eth0 
iface eth0 inet manual
auto pnet0
iface pnet0 inet dhcp
    bridge_ports eth0
    bridge_stp off

# Cloud devices
auto dummy0
iface dummy0 inet manual
    pre-up ip link add dummy0 type dummy
auto pnet1
iface pnet1 inet static
    bridge_ports dummy0
    bridge_stp off
    address 10.0.0.1
    netmask 255.0.0.0
EOF
chmod +x /etc/eve-ng-interface-tuning.sh

#SET UP INTERFACES SERVICE
cat > /etc/systemd/system/eve-ng-interface-tuning.service << EOF
[Unit]
Description=Tuning interfaces on shutdown/reboot
DefaultDependencies=no
Before=shutdown.target reboot.target

[Service]
Type=oneshot
ExecStart=/etc/eve-ng-interface-tuning.sh
TimeoutStartSec=0

[Install]
WantedBy=shutdown.target reboot.target
EOF
systemctl enable --now eve-ng-interface-tuning.service


#CONFIGURING MASQUERADING FOR INTERNET ACCESS
sed -i -e 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
iptables -A FORWARD -i pnet1 -j ACCEPT
iptables -t nat -A POSTROUTING -s 10.0.0.0/8 -o pnet0 -j MASQUERADE

#ALLOWING DHCP (UDP:67) AND DNS (UDP:53) PORTS ON PNET1 (LAB ENVIRONMENT)
iptables -A INPUT -i pnet1 -p udp -m udp --dport 67 -j ACCEPT
iptables -A INPUT -i pnet1 -p udp -m udp --dport 53 -j ACCEPT
iptables -A INPUT -i pnet1 -p tcp -m tcp --dport 1194 -j ACCEPT
iptables -A INPUT -i pnet0 -p tcp -m tcp --dport 22 -j ACCEPT
iptables-save

#MAKE IT PERMANENT
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | sudo debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | sudo debconf-set-selections
apt-get -y install iptables-persistent

#DEPLOYING AND ALLOWING 10.0.0.50 10.0.0.254 DHCP ASSIGNING
apt install -y isc-dhcp-server
sed -i -e 's/INTERFACES=""/INTERFACES="pnet1"/' /etc/default/isc-dhcp-server
echo "subnet 10.0.0.0 netmask 255.0.0.0 {range 10.0.0.50 10.0.0.254; option domain-name-servers 8.8.8.8; option subnet-mask 255.0.0.0; option routers 10.0.0.1; option broadcast-address 10.255.255.255; default-lease-time 600; max-lease-time 7200;}" >> /etc/dhcp/dhcpd.conf
systemctl restart isc-dhcp-server.service

#DEPLOYING OPENVPN
apt-get update -y
apt-get install -y openvpn easy-rsa 
make-cadir /openvpn/openvpn-ca

#CONFIGURING THE VARS FILE
cp /openvpn/openvpn-ca/vars /openvpn/openvpn-ca/vars.orig
sed -i -e 's/export KEY_COUNTRY="US"/export KEY_COUNTRY="PL"/' /openvpn/openvpn-ca/vars
sed -i -e 's/export KEY_PROVINCE="CA"/export KEY_PROVINCE="MP"/' /openvpn/openvpn-ca/vars
sed -i -e 's/export KEY_CITY="SanFrancisco"/export KEY_CITY="Krakow"/' /openvpn/openvpn-ca/vars
sed -i -e 's/export KEY_ORG="Fort-Funston"/export KEY_ORG="hardbasslab"/' /openvpn/openvpn-ca/vars
sed -i -e 's/export KEY_EMAIL="me@myhost.mydomain"/export KEY_EMAIL="admin@hardbasslab.ddns.com"/' /openvpn/openvpn-ca/vars
sed -i -e 's/export KEY_OU="MyOrganizationalUnit"/export KEY_OU="Lab"/' /openvpn/openvpn-ca/vars
sed -i -e 's/export KEY_NAME="EasyRSA"/export KEY_NAME="server"/' /openvpn/openvpn-ca/vars

cat > /openvpn/openvpn-ca/build_ca.sh << EOF
#!/usr/bin/expect -f
spawn ./build-ca
expect "Country*"
send "\r"
expect "State*"
send "\r"
expect "Locality*"
send "\r"
expect "Organization*"
send "\r"
expect "Organizational*"
send "\r"
expect "Common*"
send "eve-ng\r"
expect "Name*"
send "\r"
expect "Email*"
send "\r"
expect eof
EOF
chmod +x /openvpn/openvpn-ca/build_ca.sh

cd /openvpn/openvpn-ca/
source ./vars
./clean-all
./build_ca.sh


cat > /openvpn/openvpn-ca/build_key_server.sh << EOF
#!/usr/bin/expect -f
spawn ./build-key-server server
expect "Country*"
send "\r"
expect "State*"
send "\r"
expect "Locality*"
send "\r"
expect "Organization*"
send "\r"
expect "Organizational*"
send "\r"
expect "Common*"
send "eve-ng\r"
expect "Name*"
send "\r"
expect "Email*"
send "\r"
expect "A challenge*"
send "\r"
expect "An optional*"
send "\r"
expect "Sign*"
send "y\r"
send "y\r"
expect eof
EOF
chmod +x /openvpn/openvpn-ca/build_key_server.sh

cd /openvpn/openvpn-ca
./build_key_server.sh
./build-dh
openvpn --genkey --secret keys/ta.key

cp /openvpn/openvpn-ca/keys/ca.crt /openvpn/openvpn-ca/keys/server.crt /openvpn/openvpn-ca/keys/server.key /openvpn/openvpn-ca/keys/ta.key /openvpn/openvpn-ca/keys/dh2048.pem /etc/openvpn 

#CONFIGURING SERVER SIDE
cat > /etc/openvpn/server.conf << EOF
port 1194
proto tcp
dev tun
ca ca.crt
cert server.crt
key server.key  # This file should be kept secret
# Diffie hellman parameters.
# Generate your own with: openssl dhparam -out dh2048.pem 2048
dh dh2048.pem
server 10.1.0.0 255.255.255.0
ifconfig-pool-persist ipp.txt
keepalive 10 120
tls-auth ta.key 0 # This file is secret
cipher AES-256-CBC
auth SHA256
comp-lzo
user nobody
group nogroup
persist-key
persist-tun
status openvpn-status.log
verb 4
EOF

systemctl enable --now openvpn@server

mkdir -p /openvpn/client-configs/files
chmod 700 /openvpn/client-configs/files

#CONFIGURING CLIENT SIDE
cat > /openvpn/client-configs/base.conf << EOF
client
dev tun
proto tcp
remote hardbasslab.ddns.net 1194
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
tls-auth ta.key 1
cipher AES-256-CBC
auth SHA256
comp-lzo
verb 4
EOF

#CONFIGURING SCRIPT TO BUILD BASE CONF FILE
cat > /openvpn/client-configs/make_config.sh << 'EOF'
#!/bin/bash
cd /openvpn/openvpn-ca
source vars
./build-key-pass ${1}

# First argument: Client identifier
KEY_DIR=/openvpn/openvpn-ca/keys
OUTPUT_DIR=/openvpn/client-configs/files
BASE_CONFIG=/openvpn/client-configs/base.conf

cat ${BASE_CONFIG} \
    <(echo -e '<ca>') \
    ${KEY_DIR}/ca.crt \
    <(echo -e '</ca>\n<cert>') \
    ${KEY_DIR}/${1}.crt \
    <(echo -e '</cert>\n<key>') \
    ${KEY_DIR}/${1}.key \
    <(echo -e '</key>\n<tls-auth>') \
    ${KEY_DIR}/ta.key \
    <(echo -e '</tls-auth>') \
    > ${OUTPUT_DIR}/${1}.ovpn
EOF
chmod 700 /openvpn/client-configs/make_config.sh
chown -R root:adm /openvpn/client-configs/files
chmod g+x /openvpn/client-configs/files
##ADD CLIENT KEYS GENERATOR SCRIPT
#TO CREATE NEW OVPN PROFILE FOR A USER 
#/openvpn/client-configs/make_config.sh <username>
#scp <username>@<eve-ng>:/openvpn/client-configs/files/<username>.ovpn ~/

#INSTALLING EVE-NG
wget -O - http://www.eve-ng.net/repo/install-eve.sh | bash -i
#after this command update clients known_hosts
#after log in as root finish the installation
#after it boots after the installation add the hostname to the localhost
sed -i -e 's/127.0.0.1 localhost/127.0.0.1 localhost eve-ng/' /etc/hosts
