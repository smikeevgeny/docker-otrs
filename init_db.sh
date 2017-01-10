#!/bin/bash

/usr/bin/mysqld_safe &
sleep 5s
echo "Creating users"
echo "CREATE DATABASE otrs; GRANT ALL ON otrs.* TO 'otrs'@'localhost' IDENTIFIED BY 'g5eE94BaP' WITH GRANT OPTION; FLUSH PRIVILEGES" | mysql -u root 
echo "Loading dump"
mysql -u root -D otrs < /root/database.sql 
echo "removign temp files"
rm /root/database.sql