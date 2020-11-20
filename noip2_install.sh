#!/bin/sh
#INSTALLING DDNS CLIENT (NOIP2)
mkdir -p /etc/noip2/
cd /etc/noip2/
wget http://www.noip.com/client/linux/noip-duc-linux.tar.gz -P /etc/noip2/ && \
tar xf noip-duc-linux.tar.gz && \
cd noip-2.1.9-1 && make

cat > /etc/noip2/noip-2.1.9-1/makeinstall.sh << EOF
#!/usr/bin/expect -f
spawn make install
expect "Please enter the login/email string for no-ip.com*"
send "<your_id>\r"
sleep 5
expect "Please enter the password for user*"
send "<your_password>\r"
expect "Please enter an update interval*"
send "1\r"
expect "Do you wish to run something at successful update?*"
send "\r"
expect eof
EOF
chmod +x /etc/noip2/noip-2.1.9-1/makeinstall.sh
/etc/noip2/noip-2.1.9-1/makeinstall.sh

#SET UP DDNS CLIENT SERVICE
cat > /etc/systemd/system/noip2.service << EOF
# /etc/systemd/system/noip2.service
[Unit]
Description=NoIP2
Wants=network-online.target
After=network-online.target

[Service]
ExecStart=/usr/local/bin/noip2
Type=forking

[Install]
WantedBy=multi-user.target
EOF
systemctl enable --now noip2.service

systemctl restart noip2.service
systemctl status noip2.service
