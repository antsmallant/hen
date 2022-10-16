#!/bin/bash

# create etcd user and make auth enable
etcdctl user add root:123456
etcdctl role add root
etcdctl user grant-role root root
etcdctl auth enable