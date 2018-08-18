#! /bin/bash
# httpd root is /home/www
function install_3()
{
	yum -y install httpd
	rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
	rpm -Uvh https://mirror.webtatic.com/yum/el7/webtatic-release.rpm
	yum -y install php70w php70w-mysql p70w-pdo php70w-gd php70w-ldap php70w-odbc php70w-pear.noarch php70w-xml php70w-xmlrpc php70w-mbstring php70w-snmp php70w-soap php70w-mcrypt curl curl-devel
	mkdir /home/www
	chown apache: /home/www
	sed -i 's#DocumentRoot "/var/www/html"#DocumentRoot "/home/www"#g' /etc/httpd/conf/httpd.conf
	sed -i 's#<Directory "/var/www/html">#<Directory "/home/www">#g' /etc/httpd/conf/httpd.conf
	firewall-cmd --zone=public --add-port=80/tcp --permanent
	firewall-cmd --reload
	echo "It's ok,httpd root is:/home/www"
}

function install_1()
{
	yum install -y wget
	cd ~
	wget https://files.phpmyadmin.net/phpMyAdmin/4.8.2/phpMyAdmin-4.8.2-all-languages.tar.gz
	tar xzvf phpMyAdmin-4.8.2-all-languages.tar.gz
	mv phpMyAdmin-4.8.2-all-languages /home/www/phpdb
	cp /home/www/phpdb/config.sample.inc.php /home/www/phpdb/config.inc.php
	read -p "Type you mysql's address: 
	" mysql_ip	
	sed -i 's#'localhost'#'${mysql_ip}'#g' /home/www/phpdb/config.inc.php
	chown apache: /home/www -R
	echo "It's ok,phpmyadmin is:http://ip/phpdb"
}

setenforce 0
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
read -p "Select install: 
1.phpmyadmin4.8.2
2.zabbix
3.php7+httpd:
" select_id
if [[ $select_id == 1 ]]; then
	install_1
elif [[ $select_id == 2 ]]; then
	echo "select 2"
elif [[ $select_id == 3 ]]; then
	install_3
else
	echo "Invalid select id"
	exit
fi
