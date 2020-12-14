# Covid19 stats

This project aims to provide some script that will allow you to index some covid19 opendata into [ElasticSearch](https://www.elastic.co/elasticsearch).

Then you'll be able to make some dashboards and graphs on [Kibana](https://www.elastic.co/kibana) or [Grafana](https://grafana.com).

## Needed dependancies:

* bash >= 4
* coreutils
* jq
* getopt
* curl
* cron
* ElasticStack / ELK (ElasticSearch and Kibana are enough for this project)

## Keep the data up to date

You need to add a crontab to keep the data up to date once per day:

```shell
0 0 * * * /home/centos/covid19/get_stats.sh -a
```

## Datasources

* www.coronavirus-statistiques.com: world stats
* www.data.gouv.fr: for the French stats

## Data types

All the data are converted to a JSON document that will be indexed and contains some of the following fields:

* `vplace`: geographical place (country, continent, region, department, etc)
* `vcode`: kind of geographical place (country, continent, region, department, etc)
* `vcases`: number of positive cases or new hospitalization (depanding of the datasource)
* `vdeath`: number of death
* `vrecover`: number of recover or people that went back to their home after hospitalization
* `vrea`: number of people in intensive care
* `source`: the source of the data (governments, wikipedia, etc)

## Git repo

* Main repo: https://gitlab.comwork.io/oss/covid19
* Github mirror repo: https://github.com/idrissneumann/covid19

Both are automatically kept up to date from a private repo that also handle automatic deployment on our infrastructure.

So the commit comments are automatic messages.

## Examples of dashboard with Kibana

![d1](images/1.jpg)

![d2](images/2.jpg)

![d3](images/3.jpg)

![d4](images/4.jpg)

![d5](images/5.jpg)

## Example of using Timelion with the data

Here we subtract between the cumulative amounts of the day and the day before in order to obtain the number of new cases per day:

![v6](images/6.jpg)
