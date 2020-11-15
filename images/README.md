## Access to data

Url: https://kibana.comwork.io

### Read only

User: covid19-ro

Password: zHbCxuAe9TtRG4XHrBu3Zbhh

### Read write

User: covid19

Password: 7Lg4PxnAeJP5CJYE2nZJpxga

## Schedule on a crontab

```shell
0 0 * * * /home/centos/covid19/get_stats.sh -a
```

Once per day is alright.

## Kill the process

```shell
ps -ef|grep -i get_stats|grep covid19|awk '{print $2}'|xargs kill -9
```
