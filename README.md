# Covid19 stats

This project aims to provide some script that will allow you to index some covid19 opendata into ElasticSearch.

Then you'll be able to make some dashboards and graphs on Kibana or Grafana.

Examples using Kibana:

![d1](images/1.jpg)

![d2](images/2.jpg)

![d3](images/3.jpg)

![d4](images/4.jpg)

## Needed dependancies:

* bash
* coreutils
* jq
* getopt

## Datasources

* www.coronavirus-statistiques.com: world stats
* www.data.gouv.fr: for the french stats

## Git repo

* Main repo: https://gitlab.comwork.io/oss/covid19
* Github mirror repo: https://github.com/idrissneumann

Both are automatically update from a private repo that also handle automatic deployment on our infrastructure.

So the commit comments are automatic messages.
