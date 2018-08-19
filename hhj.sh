#! /bin/bash
# httpd root is /home/www

function install_httpd_php7()
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
	install_httpd_php7
	cd ~
	wget https://files.phpmyadmin.net/phpMyAdmin/4.8.2/phpMyAdmin-4.8.2-all-languages.tar.gz
	tar xzvf phpMyAdmin-4.8.2-all-languages.tar.gz
	mv phpMyAdmin-4.8.2-all-languages /home/www/phpdb
	cp /home/www/phpdb/config.sample.inc.php /home/www/phpdb/config.inc.php
	read -p "Type you mysql's address(default:localhost): 
	" mysql_ip	
	if [ ! $mysql_ip ]; then
		#use localhost
		sed -i 's#'localhost'#'localhost'#g' /home/www/phpdb/config.inc.php
	else
		sed -i 's#'localhost'#'${mysql_ip}'#g' /home/www/phpdb/config.inc.php
	fi 
	chown apache: /home/www -R
	echo "It's ok,phpmyadmin is:http://ip/phpdb"
}
function install_2()
{
	rpm -ivh http://repo.zabbix.com/zabbix/2.4/rhel/7/x86_64/zabbix-release-2.4-1.el7.noarch.rpm
	yum install zabbix-agent -y	
	read -p "Type you zabbix's server address: 
	" zabbix_ip
	sed -i "s#Server=127.0.0.1#Server=${zabbix_ip}#g" /etc/zabbix/zabbix_agentd.conf
	sed -i "s#ServerActive=127.0.0.1#ServerActive=${zabbix_ip}#g" /etc/zabbix/zabbix_agentd.conf
	systemctl enable zabbix-agent
	service zabbix-agent start
	systemctl enable zabbix-agent
}

function install_3()
{
	check_zabbix_rpm=`rpm -qa zabbix-agent`
	if [ -z $check_zabbix_rpm ];then
		install_2
	else
		echo "Start install zabbix mysql";
	fi
	
	#install zabbix mysql
	yum install -y https://www.percona.com/downloads/percona-monitoring-plugins/1.1.6/percona-zabbix-templates-1.1.6-1.noarch.rpm
	yum install percona-zabbix-templates -y
	cp /var/lib/zabbix/percona/templates/userparameter_percona_mysql.conf /etc/zabbix/zabbix_agentd.d/userparameter_percona_mysql.conf
	read -p "Type you mysql's address: 
		" mysql_host
	read -p "Type you mysql's username: 
		" mysql_user
	read -p "Type you mysql's password: 
		" mysql_password
	echo "<?php
				\$mysql_user = '${mysql_user}';
				\$mysql_pass = '${mysql_password}';">/var/lib/zabbix/percona/scripts/ss_get_mysql_stats.php.cnf
	echo "[client]
				user = ${mysql_user}
				password = ${mysql_password}">/var/lib/zabbix/.my.cnf
	sed -i "s#HOST=localhost#HOST=${mysql_host}#g" /var/lib/zabbix/percona/scripts/get_mysql_stats_wrapper.sh
	service zabbix-agent restart
	echo "I's OK"
}

setenforce 0
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
read -p "Select install: 
1.phpmyadmin4.8.2+php7+httpd
2.zabbix2.4
3.zabbix2.4+zabbix2.4_mysql:
" select_id
if [[ $select_id == 1 ]]; then
	install_1
elif [[ $select_id == 2 ]]; then
	install_2
elif [[ $select_id == 3 ]]; then
	install_3
else
	echo "Invalid select id"
	exit
fi
