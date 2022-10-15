create user 'hen'@'localhost' identified by '123456';
grant all privileges on *.* to 'hen'@'localhost';
create user 'hen'@'%' identified by '123456';
grant all privileges on *.* to 'hen'@'%';
flush privileges;
