#!/bin/bash

host="127.0.0.1"
port=3308
charset="utf8mb4"
user="root"
pwd="123456"

mysql -h$host -P$port -u$user -p$pwd --default-character-set=$charset < ./mysql_init_user.sql
mysql -h$host -P$port -u$user -p$pwd --default-character-set=$charset < ./mysql_init_db.sql
