# How to run
## run mysql / redis / etcd ... in docker 
* if first time
```
cd assets/tool/env
chmod +x *.sh && ./start_env.sh && echo "wait 20 seconds for mysqlserver init" && sleep 20s && ./init_mysql.sh
```
* if not the first time
```
cd assets/tool/env
./start_env.sh
```

## run servers
```
cd assets/tool
chmod +x run_allserver.sh && ./run_allserver.sh
```

## run test client
```
cd assets/tool 
chmod +x run_client.sh && ./run_client.sh
```
After run, you can type `ggl` then enter to get game list.  
See src/test/client.lua for more CMD.



# How to stop
## stop servers
```
cd assets/tool
chmod +x kill_allserver.sh && ./kill_allserver.sh
```

## stop mysql / redis / etcd ...
```
cd assets/tool/env
chmod +x *.sh && ./stop_env.sh
```