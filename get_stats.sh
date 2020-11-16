#!/usr/bin/env bash

DATA_STREAM="https://www.coronavirus-statistiques.com/corostats/openstats/open_stats_coronavirus.csv"
DATA_STREAM_FR_HOSPITAL="https://www.data.gouv.fr/fr/datasets/r/63352e38-d353-4b54-bfd1-f1b3ee1cabd7"
DATA_STREAM_FR_HOSPITAL_NEW="https://www.data.gouv.fr/fr/datasets/r/6fadff46-9efd-4c53-942a-54aca783c30c"
DATA_STREAM_FR_HOSPITAL_AGE="https://www.data.gouv.fr/fr/datasets/r/08c18e08-6780-452d-9b8c-ae244ad529b3"
DATA_STREAM_FR_HOSPITAL_ETS="https://www.data.gouv.fr/fr/datasets/r/41b9bd2a-b5b6-4271-8878-e45a8902ef00"
ELASTIC_URL="changeit"
ELASTIC_USERNAME="changeit"
ELASTIC_PASSWORD="changeit"

error() {
    echo "Error : invalid parameter !" >&2
    echo "Use -h to show all options" >&2
    exit 1
}

usage(){
    echo "Usage: ./livraison.sh [options]"
    echo "-h or --help: print help"
    echo "-a or --all: ingest all data"
    echo "--ingest-data : ingest data from www.coronavirus-statistiques.com"
    echo "--ingest-data-fr-hospital : ingest data from france with www.data.gouv.fr"
    echo "--ingest-data-fr-hospital-new : ingest data from france with www.data.gouv.fr, new cases"
    echo "--ingest-data-fr-hospital-age : ingest data from france with www.data.gouv.fr, age class"
    echo "--ingest-data-fr-hospital-ets : ingest data from france with www.data.gouv.fr, etablissements"
}

format() {
  v=$(echo "${@}"|tr -d '"'|sed 's/\r//g')
  [[ $v ]] && echo "${v}" || echo "null"  
}

format_number() {
  v=$(echo "${@}"|tr -d '"'|sed 's/\r//g')
  [[ $v =~ ^[0-9]+$ ]] && echo "${v}" || echo "-1"  
}

format_year_month() {
  format "${1}"|cut -d "-" -f1,2
}

hash_id() {
  echo "${1}"|jq -r '.vdate+.vcode+.vplace+.vsource'|base64|tr -d '='
}

hash_id_fr_hostpital() {
  echo "${1}"|jq -r '.vdate+(.vgender|tostring)+.vplace+.vsource'|base64|tr -d '='
}

hash_id_fr_hostpital_new() {
  echo "${1}"|jq -r '.vdate+.vplace+.vsource'|base64|tr -d '='
}

hash_id_fr_hostpital_age() {
  echo "${1}"|jq -r '.vdate+(.vage|tostring)+.vplace+.vsource'|base64|tr -d '='
}

hash_id_fr_hostpital_ets() {
  echo "${1}"|jq -r '.vdate+.vplace+.vsource'|base64|tr -d '='
}

ingest_data() {
  LOG_FILE="covid19.log"

  i=0
  date > "${LOG_FILE}"
  curl "${DATA_STREAM}" 2>>"${LOG_FILE}"|while IFS=';' read vdate vcode vplace vcases vdeath vrecover vsource trash; do
    if [[ $i -gt 0 ]]; then
      json="{\"vdate\":\"$(format $vdate)\",\"vcode\":\"$(format $vcode)\",\"vplace\":\"$(format $vplace)\",\"vcases\":$(format_number $vcases),\"vdeath\":$(format_number $vdeath),\"vrecover\":$(format_number $vrecover),\"vsource\":\"$(format "$vsource")\"}"
      id=$(hash_id "${json}")
      indice_url="${ELASTIC_URL}/covid19-$(format_year_month $vdate)/_doc/${id}"
      if [[ $(format $vdate) != "null" ]]; then
        curl "${indice_url}" -u "${ELASTIC_USERNAME}:${ELASTIC_PASSWORD}" -X PUT -d "${json}" -H "Content-Type: application/json" >> "${LOG_FILE}" 2>>"${LOG_FILE}"
      fi
    fi
    (( i++ ))
  done
  date >> "${LOG_FILE}"
}

ingest_data_fr_hostpital() {
  LOG_FILE="gouvfr-covid19.log"

  i=0
  date > "${LOG_FILE}"
  curl -L "${DATA_STREAM_FR_HOSPITAL}" 2>>"${LOG_FILE}"|while IFS=';' read vplace vgender vdate vcases vrea vrad vdc trash; do
    if [[ $i -gt 0 ]]; then
      json="{\"vdate\":\"$(format $vdate)\",\"vgender\":$(format_number $vgender),\"vplace\":\"$(format $vplace)\",\"vcases\":$(format_number $vcases),\"vrea\":$(format_number $vrea),\"vrecover\":$(format_number $vrad),\"vdeath\":$(format_number "$vdc"),\"vsource\":\"www.data.gouv.fr\"}"
      id=$(hash_id_fr_hostpital "${json}")
      indice_url="${ELASTIC_URL}/gouvfr-covid19-$(format_year_month $vdate)/_doc/${id}"
      if [[ $(format $vdate) != "null" ]]; then
        curl "${indice_url}" -u "${ELASTIC_USERNAME}:${ELASTIC_PASSWORD}" -X PUT -d "${json}" -H "Content-Type: application/json" >> "${LOG_FILE}" 2>>"${LOG_FILE}"
      fi
    fi
    (( i++ ))
  done
  date >> "${LOG_FILE}"
}

ingest_data_fr_hostpital_new() {
  LOG_FILE="gouvfr-new-covid19.log"

  i=0
  date > "${LOG_FILE}"
  curl -L "${DATA_STREAM_FR_HOSPITAL_NEW}" 2>>"${LOG_FILE}"|while IFS=';' read vplace vdate vcases vrea vdc vrad trash; do
    if [[ $i -gt 0 ]]; then
      json="{\"vdate\":\"$(format $vdate)\",\"vplace\":\"$(format $vplace)\",\"vcases\":$(format_number $vcases),\"vrea\":$(format_number $vrea),\"vrecover\":$(format_number $vrad),\"vdeath\":$(format_number "$vdc"),\"vsource\":\"www.data.gouv.fr\"}"
      id=$(hash_id_fr_hostpital_new "${json}")
      indice_url="${ELASTIC_URL}/gouvfr-new-covid19-$(format_year_month $vdate)/_doc/${id}"
      if [[ $(format $vdate) != "null" ]]; then
        curl "${indice_url}" -u "${ELASTIC_USERNAME}:${ELASTIC_PASSWORD}" -X PUT -d "${json}" -H "Content-Type: application/json" >> "${LOG_FILE}" 2>>"${LOG_FILE}"
      fi
    fi
    (( i++ ))
  done
  date >> "${LOG_FILE}"
}

ingest_data_fr_hostpital_age() {
  LOG_FILE="gouvfr-age-covid19.log"

  i=0
  date > "${LOG_FILE}"
  curl -L "${DATA_STREAM_FR_HOSPITAL_AGE}" 2>>"${LOG_FILE}"|while IFS=';' read vplace vage vdate vcases vrea vrad vdc trash; do
    if [[ $i -gt 0 ]]; then
      json="{\"vdate\":\"$(format $vdate)\",\"vplace\":\"$(format $vplace)\",\"vage\":$(format_number $vage),\"vcases\":$(format_number $vcases),\"vrea\":$(format_number $vrea),\"vrecover\":$(format_number $vrad),\"vdeath\":$(format_number "$vdc"),\"vsource\":\"www.data.gouv.fr\"}"
      id=$(hash_id_fr_hostpital_age "${json}")
      indice_url="${ELASTIC_URL}/gouvfr-age-covid19-$(format_year_month $vdate)/_doc/${id}"
      if [[ $(format $vdate) != "null" ]]; then
        curl "${indice_url}" -u "${ELASTIC_USERNAME}:${ELASTIC_PASSWORD}" -X PUT -d "${json}" -H "Content-Type: application/json" >> "${LOG_FILE}" 2>>"${LOG_FILE}"
      fi
    fi
    (( i++ ))
  done
  date >> "${LOG_FILE}"
}

ingest_data_fr_hostpital_ets() {
  LOG_FILE="gouvfr-ets-covid19.log"

  i=0
  date > "${LOG_FILE}"
  curl -L "${DATA_STREAM_FR_HOSPITAL_ETS}" 2>>"${LOG_FILE}"|while IFS=';' read vplace vdate vcases trash; do
    if [[ $i -gt 0 ]]; then
      json="{\"vdate\":\"$(format $vdate)\",\"vplace\":\"$(format $vplace)\",\"vcases\":$(format_number $vcases),\"vsource\":\"www.data.gouv.fr\"}"
      id=$(hash_id_fr_hostpital_ets "${json}")
      indice_url="${ELASTIC_URL}/gouvfr-ets-covid19-$(format_year_month $vdate)/_doc/${id}"
      if [[ $(format $vdate) != "null" ]]; then
        curl "${indice_url}" -u "${ELASTIC_USERNAME}:${ELASTIC_PASSWORD}" -X PUT -d "${json}" -H "Content-Type: application/json" >> "${LOG_FILE}" 2>>"${LOG_FILE}"
      fi
    fi
    (( i++ ))
  done
  date >> "${LOG_FILE}"
}

[[ $# -lt 1 ]] && error

options=$(getopt -o a,h,s -l help,all,ingest-data,ingest-data-fr-hospital,ingest-data-fr-hospital-new,ingest-data-fr-hospital-age,ingest-data-fr-hospital-ets -- "$@")
set -- $options 
while true; do 
    case "$1" in 
        -h|--help) usage ; shift ;;
        --ingest-data) ingest_data ; shift ;;
        --ingest-data-fr-hospital) ingest_data_fr_hostpital ; shift ;;
        --ingest-data-fr-hospital-new) ingest_data_fr_hostpital_new ; shift ;;
        --ingest-data-fr-hospital-age) ingest_data_fr_hostpital_age ; shift ;;
        --ingest-data-fr-hospital-ets) ingest_data_fr_hostpital_ets ; shift ;;
        -a|--all) 
          ingest_data
          ingest_data_fr_hostpital
          ingest_data_fr_hostpital_new
          ingest_data_fr_hostpital_age
          ingest_data_fr_hostpital_ets
          shift ;;
        --) shift ; break ;; 
        *) error ; shift ;;
    esac 
done
