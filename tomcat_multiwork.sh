#!/bin/sh

#  tomcat_multiwork.sh
#  
#
#  Created by HSP SI Viet Nam on 5/9/14.
#
#Check Install packet
clear
thumuc=`pwd`
sed -i 's/SELINUX=enforing/SELINUX=disabled/g' /etc/selinux/config
hsp_dir="/var/www/html/hsp_web"
ro_dir="/root"
checkjava=`rpm -qa | grep java-1.7`
if [ "$checkjava" = "" ]; then
yum -y install java-1.7.0-openjdk
fi

#check httpd
checkhttpd=`ls /etc/ | grep httpd`
if [ "$checkhttpd" = "" ]; then
yum -y install httpd httpd-*
fi

#Install Other Packet
yum -y install mlocate wget man lsof

#download packet apache
wget http://mirror.nexcess.net/apache/tomcat/tomcat-7/v7.0.54/bin/apache-tomcat-7.0.54.tar.gz
tar -xvf apache-tomcat-7.0.54.tar.gz
mv apache-tomcat-7.0.54 $hsp_dir
cd $hsp_dir
tar -cvf vwork.tar.gz conf bin logs temp webapps work
mv $hsp_dir/vwork.tar.gz $ro_dir/vwork.tar.gz
mv $thumuc/vhost.sh /usr/bin/vhost
chmod +x /usr/bin/vhost
sed -i 's/\#ServerName www.example.com:80/ServerName hsp-vn.com:80/g' /etc/httpd/conf/httpd.conf
sed -i 's/\#NameVirtualHost/NameVirtualHost/g' /etc/httpd/conf/httpd.conf
sed -i 's/ServerTokens OS/ServerTokens Prod/g' /etc/httpd/conf/httpd.conf
sed -i 's/KeepAlive Off/KeepAlive On/g' /etc/httpd/conf/httpd.conf
sed -i 's/AllowOverride None/AllowOverride All/g' /etc/httpd/conf/httpd.conf

#Restart service httpd
/etc/init.d/httpd restart
chkconfig httpd on

#adduser hsp
useradd -d $hsp_dir hsp
chown -R hsp. $hsp_dir
chmod -R 755 $hsp_dir

#Setting Iptables
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT

#clean all rules iptables
iptables -t nat -P PREROUTING ACCEPT
iptables -t nat -P OUTPUT ACCEPT
iptables -t nat -P POSTROUTING ACCEPT
iptables -t mangle -P PREROUTING ACCEPT
iptables -t mangle -P INPUT ACCEPT
iptables -t mangle -P FORWARD ACCEPT
iptables -t mangle -P OUTPUT ACCEPT
iptables -t mangle -P POSTROUTING ACCEPT

#Dell all
iptables -F
iptables -t nat -F
iptables -t mangle -F

iptables -X
iptables -t nat -X
iptables -t mangle -X

#Zero all packets and counters
iptables -Z
iptables -t nat -Z
iptables -t mangle -Z


#Set rule iptables
iptables -A INPUT -p tcp -m tcp --dport 80 -j LOG
iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A INPUT -p icmp -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m state --state NEW -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -m state --state NEW -p tcp --dport 22 -j ACCEPT
iptables -A OUTPUT -m state --state NEW -p tcp --dport 80 -j ACCEPT
iptables -A OUTPUT -m state --state NEW -p tcp --dport 22 -j ACCEPT
iptables -A OUTPUT -m state --state NEW -p tcp --dport 1521 -j ACCEPT
iptables -A OUTPUT -m state --state NEW -p tcp --dport 443 -j ACCEPT
/etc/init.d/iptables save
/etc/init.d/iptables restart
chkconfig iptables on


#Create service hsp
echo "CATALINA_HOME=/var/www/html/hsp_web" >> /etc/bashrc
cat > /etc/init.d/hspvn << hspservice
#!/bin/bash

# Apache Tomcat7: Start/Stop Chuong Trinh
#
# chkconfig: - 90 10


. /etc/init.d/functions
. /etc/sysconfig/network
export CATALINA_BASE=$hsp_dir
CATALINA_BASE=$hsp_dir
CATALINA_HOME=$hsp_dir
TOMCAT_USER=hsp
LOCKFILE=/var/lock/subsys/hsp

RETVAL=0
start(){
echo "Khoi Dong Chuong Trinh: "
su - \$TOMCAT_USER -c "\$CATALINA_HOME/bin/startup.sh"
RETVAL=\$?
echo
[ \$RETVAL -eq 0 ] && touch \$LOCKFILE
return \$RETVAL
}

stop(){
echo "Ngat Chuong Trinh: "
\$CATALINA_HOME/bin/shutdown.sh
RETVAL=\$?
echo
[ \$RETVAL -eq 0 ] && rm -f \$LOCKFILE
return \$RETVAL
}

case "\$1" in
start)
start
;;
stop)
stop
;;
restart)
stop
start
;;
status)
status tomcat
;;
*)
echo \$"Usage: \$0 {start|stop|restart|status}"
exit 1
;;
esac
exit \$?
hspservice

#End Create service
#configure service
chmod +x /etc/init.d/hspvn
chkconfig --add hspvn
chkconfig hspvn on
/etc/init.d/hspvn start


#create shell restart service
cat > /usr/bin/hspvnrestart << rsthspvn
sv=`lsof -i | grep hsp`
kill -9 \$sv
/etc/init.d/hspvn start
clear
echo "Restart HSPVN success"
rsthspvn
chmod +x /usr/bin/hspvnrestart


#Create vhost
cat > /etc/httpd/conf.d/1.conf << defaulthttp
<VirtualHost *:80>
ServerName 172.16.6.68
#    ServerAlias mid.yton.vn
ProxyPreserveHost on
ProxyRequests     off
ProxyPass / ajp://localhost:8009/
ProxyPassReverse / ajp://localhost:8009/
</VirtualHost>
defaulthttp

#Create vhost hspvn
cat > /etc/httpd/conf.d/hspvn.conf << vhhspvn
<VirtualHost *:80>
ServerName hspvn.yton.vn
#    ServerAlias mid.yton.vn
ProxyPreserveHost on
ProxyRequests     off
ProxyPass / ajp://localhost:8009/
ProxyPassReverse / ajp://localhost:8009/
</VirtualHost>
vhhspvn

/etc/init.d/httpd reload

clear
echo " Install Success Full"
yum -y update
clear
echo " Reboot Server"
echo " Please wait....."
sleep 5
reboot