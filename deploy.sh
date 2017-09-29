#!/bin/bash

# check permission
if [ `id -u` != '0' ]; then
  echo 'Error: You must be root to run this script'
  exit 1
fi

# config
dir=$(cd `dirname $0`; pwd)
installation_path='/usr/local'
version_mysql='5.7.19'
version_passenger='5.1.8'
version_nginx='1.12.1'
version_php='7.1.9'
version_docker_compose='1.16.1'
version_node='6.11.3'
version_mongodb='3.4.9'
version_python3='3.6.2'
user_http='www'
user_git='git'
user_mysql='mysql'

# installer
function installer() {
  wget -c $3
  tar zxvf $2
  mv $1 $4
}

# source installer
function sourceInstaller() {
  wget -c $3
  tar zxvf $2
  cd $1
  ./configure $4
  make && make install
  $5
  cd ..
  rm -rf $1 $2
}

# mysql需要的包
function mysqlFile() {
  wget -c https://dev.mysql.com/get/Downloads/MySQL-5.7/mysql-5.7.19.tar.gz
  wget -c http://nchc.dl.sourceforge.net/project/boost/boost/1.59.0/boost_1_59_0.tar.gz
  wget -c https://raw.githubusercontent.com/chenjiazhen/deploy/master/mysql/my.cnf
  if [ ! -f "mysql-5.7.19.tar.gz" ]; then
    echo "Did not find mysql-5.7.19.tar.gz"
    exit 1
  fi
  if [ ! -f "boost_1_59_0.tar.gz" ]; then
    echo "Did not find boost_1_59_0.tar.gz"
    exit 1
  fi
  if [ ! -f "my.cnf" ]; then
    echo "Did not find my.cnf"
    exit 1
  fi
}

# go to root directory
cd

# echo '================== hostname =================='
hostnamectl set-hostname cy

echo '================== add repo && install tools && update && upgrade =================='
# yum -y install http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-${version_epel}.noarch.rpm
yum -y install epel-release yum-utils
yum-config-manager --enable epel
yum -y update
yum -y upgrade
yum -y install autoconf bash-completion make cmake gcc gcc-c++ gcc-g77 redhat-lsb net-tools ntp wget curl zip unzip vim* emacs libcap diffutils ca-certificates psmisc libtool-libs file flex bison patch bzip2-devel c-ares-devel curl-devel e2fsprogs-devel gd-devel gettext-devel glib2-devel gmp-devel kernel-devel krb5-devel libc-client-devel libcurl-devel libevent-devel libicu-devel libidn-devel libjpeg-devel libmcrypt-devel libpng-devel libxml2-devel libXpm-devel libxslt-devel lrzsz ncurses ncurses-devel openssl-devel pcre-devel zlib-devel ImageMagick-devel subversion git mariadb re2c
# yum -y install php-cli php-fpm php-bcmath php-gd php-imap php-intl php-mbstring php-mcrypt php-mysql php-pgsql php-xml php-pclzip php-pecl-apcu php-pecl-imagick php-pecl-memcache php-pecl-memcached php-pecl-sphinx
# yum -y install ftp golang mariadb-server nodejs npm pptpd ruby siege sqlite-devel vsftpd
yum clean all

echo '================== Download mysql need to use the package =================='
mysqlFile

echo '================== boost_1_59_0 =================='
#wget -c http://nchc.dl.sourceforge.net/project/boost/boost/1.59.0/boost_1_59_0.tar.gz
tar -zxvf boost_1_59_0.tar.gz && cd boost_1_59_0/
./bootstrap.sh
./b2 stage threading=multi link=shared
./b2 install threading=multi link=shared

# go to root directory
cd

echo '================== mysql =================='
patch="${installation_path}/mysql"
# add mysql user
groupadd -r ${user_mysql} && useradd -r -g ${user_mysql} -s /bin/false -M ${user_mysql}
# install
#wget -c https://dev.mysql.com/get/Downloads/MySQL-5.7/mysql-5.7.19.tar.gz
tar -zxvf mysql-5.7.19.tar.gz && cd mysql-5.7.19
cmake -DCMAKE_INSTALL_PREFIX=${patch} -DMYSQL_DATADIR=/mydata/mysql/data -DSYSCONFDIR=/etc -DMYSQL_USER=mysql -DWITH_MYISAM_STORAGE_ENGINE=1 -DWITH_INNOBASE_STORAGE_ENGINE=1 -DWITH_ARCHIVE_STORAGE_ENGINE=1 -DWITH_MEMORY_STORAGE_ENGINE=1 -DWITH_READLINE=1 -DMYSQL_UNIX_ADDR=/var/run/mysql/mysql.sock -DMYSQL_TCP_PORT=3306 -DENABLED_LOCAL_INFILE=1 -DENABLE_DOWNLOADS=1 -DWITH_PARTITION_STORAGE_ENGINE=1 -DEXTRA_CHARSETS=all -DDEFAULT_CHARSET=utf8 -DDEFAULT_COLLATION=utf8_general_ci -DWITH_DEBUG=0  -DMYSQL_MAINTAINER_MODE=0 -DWITH_SSL:STRING=bundled -DWITH_ZLIB:STRING=bundled -DDOWNLOAD_BOOST=1 -DWITH_BOOST=/root/boost_1_59_0
make && make install
# cnf
mv /etc/my.cnf /etc/my.cnf.bak
#wget -c https://raw.githubusercontent.com/chenjiazhen/deploy/master/mysql/my.cnf
mv my.cnf /etc/my.cnf
# PATH
echo -e '\n\nexport PATH=/usr/local/mysql/bin:$PATH\n' >> /etc/profile && source /etc/profile
# 目录/mydata/mysql/data，用于存放MySQL的数据库文件。同时设置其用户和用户组为之前创建的mysql，权限为700。这样其它用户是无法进行读写的，尽量保证数据库的安全。
mkdir -p /mydata/mysql/data && chown -R root:mysql /usr/local/mysql
chown -R mysql:mysql /mydata/mysql/data 
chmod -R go-rwx /mydata/mysql/data
# MySQL日志存放目录以及权限都是根据前面my.cnf文件写的，也就是两者需要保持一致。
mkdir -p /var/run/mysql && mkdir -p /var/log/mysql 
chown -R mysql:mysql /var/log/mysql && chown -R mysql:mysql /var/run/mysql
# 初始化MySQL自身的数据库
mysqld --initialize-insecure --user=mysql --basedir=/usr/local/mysql --datadir=/mydata/mysql/data
# 设置开机启动
cp /usr/local/mysql/support-files/mysql.server /etc/init.d/mysqld 
chmod +x /etc/init.d/mysqld
chkconfig --add mysqld
chkconfig mysqld on
# 初始化MySQL数据库的root用户密码
# mysql_secure_installation
# 将MySQL数据库的动态链接库共享至系统链接库
echo '/usr/local/mysql/lib' > /etc/ld.so.conf.d/mysql.conf
ldconfig
# 自动生成指定的临时目录
echo -e "d /var/run/mysql 0755 mysql mysql" >> /usr/lib/tmpfiles.d/var.conf
# Delete the package
cd ~ && rm -rf boost_1_59_0* && rm -rf mysql-5.7.19* && rm -rf my.cnf

echo '================== nginx =================='
name="nginx-${version_nginx}"
tar="${name}.tar.gz"
path="${installation_path}/nginx"
sourceInstaller ${name} ${tar} http://nginx.org/download/${tar} " --prefix=${path} --user=${user_http} --group=${user_http} --with-http_gzip_static_module --with-http_image_filter_module=dynamic --with-http_ssl_module --with-http_stub_status_module --with-http_xslt_module=dynamic --with-mail=dynamic --with-stream=dynamic --with-compat --add-dynamic-module=${passenger_nginx_addon_dir}"
echo "export PATH=${path}/sbin:"'$PATH' > /etc/profile.d/nginx.sh
source /etc/profile.d/nginx.sh
setsebool -P httpd_can_network_connect=1
wget -c https://github.com/xiewulong/nginx/raw/master/www.service.sample
mv www.service.sample /usr/lib/systemd/system/www.service

echo '================== php =================='
name="php-${version_php}"
tar="${name}.tar.gz"
path="${installation_path}/php"
sourceInstaller ${name} ${tar} http://cn2.php.net/distributions/${tar} " --prefix=${path} --with-config-file-path=${path}/etc --enable-fpm --with-fpm-user=${user_http} --with-fpm-group=${user_http} --enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-iconv-dir --with-freetype-dir=${installation_path}/freetype --with-jpeg-dir --with-png-dir --with-zlib --with-libxml-dir=/usr --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization --with-curl --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --with-mcrypt --enable-ftp --with-gd --enable-gd-native-ttf --with-openssl --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-zip --enable-soap --with-gettext --enable-opcache --with-xsl" "cp php.ini-development php.ini-production ${path}/etc/"
echo "export PATH=${path}/sbin:${path}/bin:"'$PATH' > /etc/profile.d/php.sh
source /etc/profile.d/php.sh
cp ${path}/etc/php-fpm.conf.default ${path}/etc/php-fpm.conf
cp ${path}/etc/php.ini-production ${path}/etc/php.ini
cp ${path}/etc/php-fpm.d/www.conf.default ${path}/etc/php-fpm.d/www.conf
sed -i 's/short_open_tag =.*/short_open_tag = On/g' ${path}/etc/php.ini
sed -i 's/;cgi.fix_pathinfo=.*/cgi.fix_pathinfo=0/g' ${path}/etc/php.ini
sed -i 's/expose_php =.*/expose_php = Off/g' ${path}/etc/php.ini
sed -i 's/post_max_size =.*/post_max_size = 60M/g' ${path}/etc/php.ini
sed -i 's/upload_max_filesize =.*/upload_max_filesize = 60M/g' ${path}/etc/php.ini
sed -i 's/max_execution_time =.*/max_execution_time = 120/g' ${path}/etc/php.ini
sed -i 's/;date.timezone =.*/date.timezone = PRC/g' ${path}/etc/php.ini
pear config-set php_ini ${path}/etc/php.ini
pecl config-set php_ini ${path}/etc/php.ini
# pecl install apcu imagick memcache memcached swoole
# mkdir -p /var/lib/php/session
# chown ${user_http}:${user_http} /var/lib/php/session
wget -c https://github.com/xiewulong/deploy/raw/master/systemd/php-fpm.service
mv php-fpm.service /usr/lib/systemd/system/

echo 'Successful installation'