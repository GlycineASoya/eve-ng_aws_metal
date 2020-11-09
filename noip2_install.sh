#!/bin/sh
#INSTALLING DDNS CLIENT (NOIP2)
wget http://www.noip.com/client/linux/noip-duc-linux.tar.gz -P /etc/noip2/ && \
tar xf noip-duc-linux.tar.gz && \
cd noip-2.1.9-1 && make

cat > /etc/noip2/makeinstall.sh << EOF
#!/usr/bin/expect -f
spawn make install
expect "Please enter the login/email string for no-ip.com*"
send "ivlevinsky@gmail.com\r"
expect "Please enter the password for user*"
send "qp#qb4xB5J2ndv+\r"
expect "Please enter an update interval*"
send "1\r"
expect "Do you wish to run something at successful update?*"
send "\r"
expect eof
EOF
chmod +x /etc/noip2/makeinstall.sh
/etc/noip2/makeinstall.sh

#SET UP DDNS CLIENT SERVICE
cat > /etc/systemd/system/noip2.service << EOF
# /etc/systemd/system/noip2.service
[Unit]
Description=NoIP2

[Service]
ExecStart=/usr/local/bin/noip2
Type=forking

[Install]
WantedBy=multi-user.target
EOF
systemctl enable noip2.service
