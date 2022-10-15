#!/bin/bash

host="127.0.0.1"
port=3308
charset="utf8mb4"
user="root"
pwd="123456"

mysql -h$host -P$port -u$user -p$pwd --default-character-set=$charset  -e "delete from mysql.user where user = 'hen';flush privileges;"
mysql -h$host -P$port -u$user -p$pwd --default-character-set=$charset  -e "drop database if exists hen;"