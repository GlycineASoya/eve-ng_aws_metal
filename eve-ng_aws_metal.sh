At the first time:
On the server:
useradd -m -G sudo,adm <username>
On the client:
ssh-keygen -b 4096 -t ed25519 -f <output_file>
ssh-add <private_key>
ssh-copy-id [-i <pem_file>.pem] root@<host>
OR
scp [-i <pem_file>.pem] <output_file>.pub root@<host>:/home/<username>/.ssh/authorized_keys

The client side
ssh-keygen -b 4096 -t ed25519 -f <output_file>
ssh-copy-id -i <output_file> <username>@<host>
OR
scp <output_file>.pub <username>@<host>:/home/<username>/.ssh

Run all as root
The server side optional:
useradd -m -G sudo <username>
passwd -e <username>
userdel -r <username>

The server side
mkdir /etc/skel/.ssh
sed -i -e 's/# auth       required   pam_wheel.so/ auth       required   pam_wheel.so/' /etc/pam.d/su
sed -i -e 's/PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i -e 's/#AuthorizedKeysFile/AuthorizedKeysFile' /etc/ssh/sshd_config
sed -i -e 's/PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i -e 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i -e 's/nameserver 0.0.0.0/nameserver 8.8.8.8/' /etc/resolv.conf

sed -i -e 's/GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="net.ifnames=0 noquiet"/' /etc/default/grub
update-grub

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


wget -O - http://www.eve-ng.net/repo/install-eve.sh | bash -i
#after this command update clients known_hosts


apt update -y
apt install -y dnsmasq
sed -i -e 's/#listen-address=/listen-address=::1,127.0.0.1,10.0.0.1/' /etc/dnsmasq.conf
sed -i -e 's/#interface=/interface=pnet1/' /etc/dnsmasq.conf
sed -i -e 's/#dhcp-range=192.168.0.50,192.168.0.150,255.255.255.0,12h/dhcp-range=10.0.0.100,10.0.1.254,255.255.255.0,12h/' /etc/dnsmasq.conf
sed -i -e 's/#dhcp-leasefile=/dhcp-leasefile=/' /etc/dnsmasq.conf
sed -i -e 's/#dhcp-authoritative/dhcp-authoritative/' /etc/dnsmasq.conf
