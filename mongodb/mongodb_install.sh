#!/bin/bash

# check permission
if [ `id -u` != '0' ]; then
  echo 'Error: You must be root to run this script'
  exit 1
fi

# config
dir=$(cd `dirname $0`; pwd)
installation_path='/usr/local'
user_mongodb='mongodb'

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

# go to root directory
cd

echo "================== ${user_mongodb} =================="
tar -zxvf mongodb-linux-x86_64-rhel62-3.4.10.tgz -C /usr/local/
cd /usr/local/
mv mongodb-linux-x86_64-rhel62-3.4.10/ mongodb

echo "================== PATH =================="
echo -e '\n\nexport PATH=/usr/local/mongodb/bin:$PATH\n' >> /etc/profile && source /etc/profile

echo "================== file =================="
mkdir -p /data/mongodb/journal
mkdir -p /data/mongodb/log
touch /data/mongodb/log/mongodb.log

echo "================== conf =================="
cd /etc/
wget -c https://raw.githubusercontent.com/chenjiazhen/deploy/master/mongodb/mongodb.conf
echo "================== ${user_mongodb} =================="
useradd ${user_mongodb} -M -s /sbin/nologin
chown -R mongodb:mongodb /data/mongodb

echo '================== start_up_sh =================='
cd /etc/init.d/
wget https://raw.githubusercontent.com/chenjiazhen/deploy/master/mongodb/mongodb_start_up.sh
mv mongodb_start_up.sh mongodb

chkconfig --add mongodb
chkconfig mongodb on
chmod +x  /etc/init.d/mongodb

echo 'Successful installation'
echo 'service mongod start'