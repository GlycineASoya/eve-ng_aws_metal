#!/bin/sh
#At the first time:
#On the server:
#useradd -m -G sudo,adm <username>
#On the client:
#ssh-keygen -b 4096 -t ed25519 -f <output_file>
#ssh-add <private_key>
#ssh-copy-id [-i <pem_file>.pem] root@<host>
#OR
#scp [-i <pem_file>.pem] <output_file>.pub root@<host>:/home/<username>/.ssh/authorized_keys

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
apt-get install -y expect

#CREATING IN SKELETON FOR NEW USERS .SSH DIR
mkdir /etc/skel/.ssh

#ENABLING WHEEL
sed -i -e 's/# auth       required   pam_wheel.so/ auth       required   pam_wheel.so/' /etc/pam.d/su

#CONFIGURING ONLY PUBKEY AUTHENTICATION
sed -i -e 's/PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i -e 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config

#ADDING GOOGLE DNS NAMESERVER
sed -i -e 's/nameserver 0.0.0.0/nameserver 8.8.8.8/' /etc/resolv.conf

#USING ETH NAMING IN GRUB
sed -i -e 's/GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="net.ifnames=0 noquiet"/' /etc/default/grub
update-grub

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
systemctl enable eve-ng-interface-tuning.service


#INSTALLING EVE-NG
wget -O - http://www.eve-ng.net/repo/install-eve.sh | bash -i
#after this command update clients known_hosts

#CONFIGURING MASQUERADING FOR INTERNET ACCESS
echo "1" > /proc/sys/net/ipv4/ip_forward
iptables -A FORWARD -i pnet1 -j ACCEPT
iptables -t nat -A POSTROUTING -s 10.0.0.0/8 -o pnet0 -j MASQUERADE

#ALLOWING DHCP (UDP:67) AND DNS (UDP:53) PORTS ON PNET1 (LAB ENVIRONMENT)
iptables -A INPUT -i pnet1 -p udp -m udp --dport 67 -j ACCEPT
iptables -A INPUT -i pnet1 -p udp -m udp --dport 53 -j ACCEPT

apt update -y
apt install -y dnsmasq
sed -i -e 's/#listen-address=/listen-address=::1,127.0.0.1,10.0.0.1/' /etc/dnsmasq.conf
sed -i -e 's/#interface=/interface=pnet1/' /etc/dnsmasq.conf
sed -i -e 's/#dhcp-range=192.168.0.50,192.168.0.150,255.255.255.0,12h/dhcp-range=10.0.0.50,10.0.0.254,255.255.255.0,12h/' /etc/dnsmasq.conf
sed -i -e 's/#dhcp-leasefile=/dhcp-leasefile=/' /etc/dnsmasq.conf
sed -i -e 's/#dhcp-authoritative/dhcp-authoritative/' /etc/dnsmasq.conf
