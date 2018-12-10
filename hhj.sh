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
	read -p "Type your mysql's address(default:localhost): 
	" mysql_ip	
	if [ ! $mysql_ip ]; then
		#use localhost
		sed -i 's#'localhost'#'localhost'#g' /home/www/phpdb/config.inc.php
	else
		sed -i 's#'localhost'#'${mysql_ip}'#g' /home/www/phpdb/config.inc.php
	fi 
	chown apache: /home/www -R
	service httpd start
	systemctl enable httpd
	echo "It's ok,phpmyadmin is:http://ip/phpdb"
}
function install_2()
{
	rpm -ivh http://repo.zabbix.com/zabbix/2.4/rhel/7/x86_64/zabbix-release-2.4-1.el7.noarch.rpm
	yum install zabbix-agent -y	
	read -p "Type your zabbix's server address: 
	" zabbix_ip
	sed -i "s#Server=127.0.0.1#Server=${zabbix_ip}#g" /etc/zabbix/zabbix_agentd.conf
	sed -i "s#ServerActive=127.0.0.1#ServerActive=${zabbix_ip}#g" /etc/zabbix/zabbix_agentd.conf
	firewall-cmd --zone=public --add-port=10050/tcp --permanent
	firewall-cmd --reload
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
	read -p "Type your mysql's address: 
		" mysql_host
	read -p "Type your mysql's username: 
		" mysql_user
	read -p "Type your mysql's password: 
		" mysql_password
	echo "<?php
				\$mysql_user = '${mysql_user}';
				\$mysql_pass = '${mysql_password}';">/var/lib/zabbix/percona/scripts/ss_get_mysql_stats.php.cnf
	echo "[client]
			host = ${mysql_host}
			user = ${mysql_user}
			password = ${mysql_password}">/var/lib/zabbix/.my.cnf
	sed -i "s#HOST=localhost#HOST=${mysql_host}#g" /var/lib/zabbix/percona/scripts/get_mysql_stats_wrapper.sh
	service zabbix-agent restart
	echo "I's OK"
}
function install_4()
{
	yum install ntp ntpdate -y
	echo "20 */1 * * * /usr/sbin/ntpdate -u cn.pool.ntp.org" >> /var/spool/cron/root
	/usr/sbin/ntpdate -u cn.pool.ntp.org
	systemctl enable ntpd.service
	systemctl start ntpd
	firewall-cmd --add-service=ntp --permanent
	firewall-cmd --reload
	echo "server ntp.sjtu.edu.cn" >> /etc/ntp.conf
	echo "server 127.127.1.0 fudge" >> /etc/ntp.conf
	echo "127.127.1.0 stratum 8" >> /etc/ntp.conf
	sed -i "s/restrict default nomodify notrap nopeer noquery/restrict default nomodify/g" /etc/ntp.conf
	sed -i "s/restrict 127.0.0.1/#restrict 127.0.0.1/g" /etc/ntp.conf
	sed -i "s/restrict ::1/#restrict ::1/g" /etc/ntp.conf
	echo "I's ok"
}
function install_5()
{
	read -p "Type mysql's data dir:(recommend is: /var/lib/mysql)
		" mysql_data_dir
	cd ~
	yum install -y wget
	wget https://dev.mysql.com/get/Downloads/MySQL-8.0/mysql-8.0.12-1.el7.x86_64.rpm-bundle.tar
	yum install -y perl-Module-Install.noarch
	tar xvf mysql-8.0.12-1.el7.x86_64.rpm-bundle.tar
	rm -rf mysql-community-server-minimal-*
	yum install -y mysql-community*.rpm
	mkdir -p ${mysql_data_dir}
	sed -i "s#datadir=/var/lib/mysql#datadir=${mysql_data_dir}#g" /etc/my.cnf
	mysqld --initialize --user=mysql  --datadir=${mysql_data_dir}
	service mysqld start
	systemctl enable mysqld
	
	#change the password
	mysql_old_password=`cat /var/log/mysqld.log | grep password | head -1 | rev  | cut -d ' ' -f 1 | rev`
	mysql_new_password=`date +%s | sha256sum | base64 | head -c 20`
	mysql -u root  --connect-expired-password -p${mysql_old_password} -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${mysql_new_password}'"
	firewall-cmd --zone=public --add-port=3306/tcp --permanent
	firewall-cmd --reload
	echo "I's ok,You mysql version is:8.0.12 root password is:${mysql_new_password}"
}

setenforce 0
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
read -p "Select install: 
1.phpmyadmin4.8.2+php7+httpd
2.zabbix2.4
3.zabbix2.4+percona-zabbix-mysql
4.ntp server
5.mysql8.0.12:
" select_id
if [[ $select_id == 1 ]]; then
	install_1
elif [[ $select_id == 2 ]]; then
	install_2
elif [[ $select_id == 3 ]]; then
	install_3
elif [[ $select_id == 4 ]]; then
	install_4
elif [[ $select_id == 5 ]]; then
	install_5
elif [[ $select_id == 6 ]]; then
	install_httpd_php7
else
	echo "Invalid select id"
	exit
fi