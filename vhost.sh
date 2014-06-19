#!/bin/sh

#  create_work_tomcat.sh
#  
#
#  Created by HSP SI Viet Nam on 5/9/14.
#

tenshell=`echo $0`
echo "Script Chi Dung Rieng Cho Da Nang"
number_work=`ls /var/www/html | wc -l`
echo $number_work

#configure port
if [ "$number_work" -le 9 ]; then
sv_port="8"$number_work"05"
sv_connecter="8"$number_work"80"
sv_connecport="8"$number_work"09"
fi

#configure port
if [ "$number_work" -gt 9 ]; then
sv_port="8"$number_work"5"
sv_connecter="8"$number_work"8"
sv_connecport="8"$number_work"9"
fi

echo "Dien ten sub domain ma ban muon tao:"
echo "Luu Y; Chi dien sub khong dien domain."
echo "Domain mac dinh: Yton.vn"
read -p"Sub Domain: " sdm

#check subdomain rong
if [ "$sdm" = "" ]; then
    echo "sub doamin khong duoc la rong"
    echo " Dien lai"
    sleep 3
    sh $tenshell
    exit 1
fi

#check trung subdomain
check_sdm=`ls /etc/httpd/conf.d/ | grep $sdm.yton.vn.conf`
if [ "$check_sdm" != "" ]; then
clear
    echo "Sub Domain "$sdm".yton.vn.conf da ton tai"
    echo "Vui long Dien lai Sub Domain khac"
    echo "Nhap Lai"
    sh $tenshell
    exit 1
fi

#create subdomain
mkdir -p /var/www/html/$sdm
cd
cp vwork.tar.gz /var/www/html/$sdm/vwork.tar.gz
cd /var/www/html/$sdm
tar -xvf vwork.tar.gz
rm -rf vwork.tar.gz
cd
chown -R hsp. /var/www/html/$sdm
chmod -R 755 /var/www/html/$sdm
chmod -R +rx /var/www/html
#change port conflig
cat > /var/www/html/$sdm/conf/server.xml << eof
<?xml version='1.0' encoding='utf-8'?>
<Server port="$sv_port" shutdown="SHUTDOWN">
<Listener className="org.apache.catalina.core.AprLifecycleListener" SSLEngine="on" />
<Listener className="org.apache.catalina.core.JasperListener" />
<Listener className="org.apache.catalina.core.JreMemoryLeakPreventionListener" />
<Listener className="org.apache.catalina.mbeans.GlobalResourcesLifecycleListener" />
<Listener className="org.apache.catalina.core.ThreadLocalLeakPreventionListener" />
<GlobalNamingResources>
<Resource name="UserDatabase" auth="Container"
type="org.apache.catalina.UserDatabase"
description="User database that can be updated and saved"
factory="org.apache.catalina.users.MemoryUserDatabaseFactory"
pathname="conf/tomcat-users.xml" />
</GlobalNamingResources>
<Service name="Catalina">
<Connector port="$sv_connecter" protocol="HTTP/1.1"
connectionTimeout="20000"
redirectPort="8443" />
<Connector port="$sv_connecport" protocol="AJP/1.3" redirectPort="8443" />
<Engine name="Catalina" defaultHost="localhost">
<Realm className="org.apache.catalina.realm.LockOutRealm">
<Realm className="org.apache.catalina.realm.UserDatabaseRealm"
resourceName="UserDatabase"/>
</Realm>

<Host name="localhost"  appBase="webapps"
unpackWARs="true" autoDeploy="true">
<Valve className="org.apache.catalina.valves.AccessLogValve" directory="logs"
prefix="localhost_access_log." suffix=".txt"
pattern="%h %l %u %t &quot;%r&quot; %s %b" />

</Host>
</Engine>
</Service>
</Server>
eof



#create service
cat > /usr/bin/start_$sdm << eof
export CATALINA_HOME=/var/www/html/hsp_web
export CATALINA_BASE=/var/www/html/$sdm
cd \$CATALINA_HOME/bin
./startup.sh
eof
chmod +x /usr/bin/start_$sdm

cat > /usr/bin/stop_$sdm << eof
export CATALINA_HOME=/var/www/html/hsp_web
export CATALINA_BASE=/var/www/html/$sdm
cd \$CATALINA_HOME/bin
./shutdown.sh
eof
chmod +x /usr/bin/stop_$sdm


#create shell restart service
cat > /usr/bin/reset_$sdm << rsthspvn
sv=\`lsof -i | grep $sdm\`
kill -9 \$sv
/usr/bin/start_$sdm start
clear
echo "Restart $sdm success"
rsthspvn

chmod +x /usr/bin/reset_$sdm


#Create vhost hspvn
cat > /etc/httpd/conf.d/$sdm.yton.vn.conf << vhhspvn
<VirtualHost *:80>
ServerName $sdm.yton.vn
#    ServerAlias mid.yton.vn
ProxyPreserveHost on
ProxyRequests     off
ProxyPass / ajp://localhost:$sv_connecport/
ProxyPassReverse / ajp://localhost:$sv_connecport/
</VirtualHost>
vhhspvn

/etc/init.d/httpd reload
/usr/bin/start_$sdm start
clear
echo " Install Success Full"
