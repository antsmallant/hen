# What
* a game server engine base on [skynet](https://github.com/cloudwu/skynet)
* distributed support base on etcd, easily expand to support millions online
* easy to start a new game project


# Doc
* architecture: doc/arch.md


# Get started
## clone
```
git clone https://github.com/antsmallant/hen.git
```

## install dependencies
* for ubuntu
```
sudo apt install gcc
sudo apt install g++
sudo apt install make
sudo apt install autoconf
sudo apt install libreadline-dev
```
* for centos
```
sudo yum install gcc
sudo yum install g++
sudo yum install make
sudo yum install autoconf
sudo yum install readline-devel
```

## make
```
cd hen && git submodule update --init --recursive && make linux
```

## run
* read ./assets/README.md, follow the steps


