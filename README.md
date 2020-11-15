# Covid19 stats

This project aims to provide some script that will allow you to index some covid19 opendata into [ElasticSearch](https://www.elastic.co/elasticsearch).

Then you'll be able to make some dashboards and graphs on [Kibana](https://www.elastic.co/kibana) or [Grafana](https://grafana.com).

## Needed dependancies:

* bash
* coreutils
* jq
* getopt
* cron

## Keep the data up to date

You need to add a crontab to keep the data up to date once per day:

```shell
0 0 * * * /home/centos/covid19/get_stats.sh -a
```

## Datasources

* www.coronavirus-statistiques.com: world stats
* www.data.gouv.fr: for the french stats

## Git repo

* Main repo: https://gitlab.comwork.io/oss/covid19
* Github mirror repo: https://github.com/idrissneumann/covid19

Both are automatically update from a private repo that also handle automatic deployment on our infrastructure.

So the commit comments are automatic messages.

## Examples of dashboard with Kibana

![d1](images/1.jpg)

![d2](images/2.jpg)

![d3](images/3.jpg)

![d4](images/4.jpg)
