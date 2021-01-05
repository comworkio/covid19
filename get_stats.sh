#!/usr/bin/env bash

DATA_STREAM="https://www.coronavirus-statistiques.com/corostats/openstats/open_stats_coronavirus.csv"
DATA_STREAM_FR_HOSPITAL="https://www.data.gouv.fr/fr/datasets/r/63352e38-d353-4b54-bfd1-f1b3ee1cabd7"
DATA_STREAM_FR_HOSPITAL_NEW="https://www.data.gouv.fr/fr/datasets/r/6fadff46-9efd-4c53-942a-54aca783c30c"
DATA_STREAM_FR_HOSPITAL_AGE="https://www.data.gouv.fr/fr/datasets/r/08c18e08-6780-452d-9b8c-ae244ad529b3"
DATA_STREAM_FR_HOSPITAL_ETS="https://www.data.gouv.fr/fr/datasets/r/41b9bd2a-b5b6-4271-8878-e45a8902ef00"
DATA_VACCINE_FR="https://raw.githubusercontent.com/rozierguillaume/vaccintracker/main/data.csv"
DATA_VACCINE_WORLD_LOCATIONS="https://raw.githubusercontent.com/owid/covid-19-data/master/public/data/vaccinations/locations.csv"
DATA_VACCINE_WORLD_VACCINATIONS="https://raw.githubusercontent.com/owid/covid-19-data/master/public/data/vaccinations/vaccinations.csv"

[[ ! $ELASTIC_URL ]] && export ELASTIC_URL="changeit"
[[ ! $ELASTIC_USERNAME ]] && export ELASTIC_USERNAME="changeit"
[[ ! $ELASTIC_PASSWORD ]] && export ELASTIC_PASSWORD="changeit"
[[ ! $WAIT_TIME ]] && export WAIT_TIME=86400
[[ ! $DEBUG_MODE ]] && export DEBUG_MODE="disabled"
[[ ! $DAEMON_MODE ]] && export DAEMON_MODE="disabled"
[[ ! $CONTAINER_MODE ]] && export CONTAINER_MODE="disabled"

error() {
  echo "Error: invalid parameter !" >&2
  echo "Use -h to show all options" >&2
  exit 1
}

usage() {
  echo "Usage: ./get_stats.sh [options]"
  echo "-h or --help: print help"
  echo "-a or --all: ingest all data"
  echo "-d or --debug: enable debug traces (override the DEBUG_MODE env variable)"
  echo "--daemon-mode: enable daemon mode (override the DAEMON_MODE env variable)"
  echo "--ingest-data: ingest data from www.coronavirus-statistiques.com"
  echo "--ingest-data-fr-hospital: ingest data from france with www.data.gouv.fr"
  echo "--ingest-data-fr-hospital-new: ingest data from france with www.data.gouv.fr, new cases"
  echo "--ingest-data-fr-hospital-age: ingest data from france with www.data.gouv.fr, age classes"
  echo "--ingest-data-fr-hospital-ets: ingest data from france with www.data.gouv.fr, etablissements"
  echo "--ingest-data-fr-vaccine: ingest vaccine data from france with Guillaume Rozier (on github)"
  echo "--ingest-data-world-vaccine-locations: ingest worldwide vaccine data locations (on github)"
  echo "--ingest-data-world-vaccinations: ingest worldwide vaccine data vaccinations (on github)"
}

format() {
  v=$(echo "${@}"|tr -d '"'|sed 's/\r//g')
  [[ $v ]] && echo "${v}" || echo "null"  
}

format_number() {
  v=$(echo "${@}"|tr -d '"'|sed 's/\r//g')
  [[ $v =~ ^[0-9\.]+$ ]] && echo "${v}" || echo "-1"  
}

format_year_month() {
  format "${1}"|cut -d "-" -f1,2
}

hash_id() {
  echo "${1}"|jq -r "${2}"|base64|tr -d '='
}

get_usecase_prefix() {
  ext=""
  prefix=""
  if [[ $1 && $1 =~ .*vaccin.* ]]; then 
    prefix="vaccine-"
  elif [[ $1 && $1 != "null" ]]; then
    prefix="gouvfr-"
  fi

  [[ $1 && $1 != "null" && $1 != "gouvfr" && $1 != "vaccine" ]] && ext="-${1}"
  echo "${prefix}covid19${ext}"
}

get_log_file_name() {
  echo "$(get_usecase_prefix $1).log"
}

get_indice_name() {
  echo "$(get_usecase_prefix ${1})-$(format_year_month $(echo "${2}"|jq -r '.vdate'))"
}

start_log() {
  usecase="${1}"
  [[ $CONTAINER_MODE == "enabled" ]] && date || date > $(get_log_file_name "${usecase}")
}

end_log() {
  usecase="${1}"
  [[ $CONTAINER_MODE == "enabled" ]] && bash -c "echo ''; date" || bash -c "echo ''; date" >> $(get_log_file_name "${usecase}")
}

invoke_url() {
  url="${1}"
  usecase="${2}"
  [[ $CONTAINER_MODE == "enabled" ]] && curl -L "${url}" || curl -L "${url}" 2>>$(get_log_file_name "${usecase}")
}

push_document() {
  json="${1}"
  jsonquery="${2}"
  usecase="${3}"
  [[ $DEBUG_MODE == "enabled" ]] && set -x

  log_file=$(get_log_file_name "${usecase}")
  id=$(hash_id "${json}" "${jsonquery}")

  indice_url="${ELASTIC_URL}/$(get_indice_name "${usecase}" "${json}")/_doc/${id}"
  content_type="Content-Type: application/json"
  if [[ $(echo "${json}"|jq -r '.vdate') != "null" ]]; then
    if [[ $CONTAINER_MODE == "enabled" ]]; then
      curl "${indice_url}" -u "${ELASTIC_USERNAME}:${ELASTIC_PASSWORD}" -X PUT -d "${json}" -H "${content_type}"
    else
      curl "${indice_url}" -u "${ELASTIC_USERNAME}:${ELASTIC_PASSWORD}" -X PUT -d "${json}" -H "${content_type}" >> "${log_file}" 2>>"${log_file}"
    fi
  fi
}

ingest_data() {
  line=0
  usecase=""
  start_log "${usecase}"
  invoke_url "${DATA_STREAM}" "${usecase}"|while IFS=';' read vdate vcode vplace vcases vdeath vrecover vsource trash; do
    if [[ $line -gt 0 ]]; then
      json="{\"vdate\":\"$(format $vdate)\",\"vcode\":\"$(format $vcode)\",\"vplace\":\"$(format $vplace)\",\"vcases\":$(format_number $vcases),\"vdeath\":$(format_number $vdeath),\"vrecover\":$(format_number $vrecover),\"vsource\":\"$(format "$vsource")\"}"
      push_document "${json}" '.vdate+.vcode+.vplace+.vsource'
    fi
    (( line++ ))
  done
  end_log
}

ingest_data_fr_hostpital() {
  line=0
  usecase="gouvfr"
  start_log "${usecase}"
  invoke_url "${DATA_STREAM_FR_HOSPITAL}" "${usecase}"|while IFS=';' read vplace vgender vdate vcases vrea vrad vdc trash; do
    if [[ $line -gt 0 ]]; then
      json="{\"vdate\":\"$(format $vdate)\",\"vgender\":$(format_number $vgender),\"vplace\":\"$(format $vplace)\",\"vcases\":$(format_number $vcases),\"vrea\":$(format_number $vrea),\"vrecover\":$(format_number $vrad),\"vdeath\":$(format_number "$vdc"),\"vsource\":\"www.data.gouv.fr\"}"
      push_document "${json}" '.vdate+(.vgender|tostring)+.vplace+.vsource' "${usecase}"
    fi
    (( line++ ))
  done
  end_log "${usecase}"
}

ingest_data_fr_hostpital_new() {
  line=0
  usecase="new"
  start_log "${usecase}"
  invoke_url "${DATA_STREAM_FR_HOSPITAL_NEW}" "${usecase}"|while IFS=';' read vplace vdate vcases vrea vdc vrad trash; do
    if [[ $line -gt 0 ]]; then
      json="{\"vdate\":\"$(format $vdate)\",\"vplace\":\"$(format $vplace)\",\"vcases\":$(format_number $vcases),\"vrea\":$(format_number $vrea),\"vrecover\":$(format_number $vrad),\"vdeath\":$(format_number "$vdc"),\"vsource\":\"www.data.gouv.fr\"}"
      push_document "${json}" '.vdate+.vplace+.vsource' "${usecase}"
    fi
    (( line++ ))
  done
  end_log "${usecase}"
}

ingest_data_fr_hostpital_age() {
  line=0
  usecase="age"
  start_log "${usecase}"
  invoke_url "${DATA_STREAM_FR_HOSPITAL_AGE}" "${usecase}"|while IFS=';' read vplace vage vdate vcases vrea vrad vdc trash; do
    if [[ $line -gt 0 ]]; then
      json="{\"vdate\":\"$(format $vdate)\",\"vplace\":\"$(format $vplace)\",\"vage\":$(format_number $vage),\"vcases\":$(format_number $vcases),\"vrea\":$(format_number $vrea),\"vrecover\":$(format_number $vrad),\"vdeath\":$(format_number "$vdc"),\"vsource\":\"www.data.gouv.fr\"}"
      push_document "${json}" '.vdate+(.vage|tostring)+.vplace+.vsource' "${usecase}"
    fi
    (( line++ ))
  done
  end_log "${usecase}"
}

ingest_data_fr_hostpital_ets() {
  line=0
  usecase="ets"
  start_log "${usecase}"
  invoke_url "${DATA_STREAM_FR_HOSPITAL_ETS}" "${usecase}"|while IFS=';' read vplace vdate vcases trash; do
    if [[ $line -gt 0 ]]; then
      json="{\"vdate\":\"$(format $vdate)\",\"vplace\":\"$(format $vplace)\",\"vcases\":$(format_number $vcases),\"vsource\":\"www.data.gouv.fr\"}"
      push_document "${json}" '.vdate+.vplace+.vsource' "${usecase}"
    fi
    (( line++ ))
  done
  end_log "${usecase}"
}

ingest_data_fr_vaccine() {
  line=0
  usecase="vaccinefr"
  start_log "${usecase}"
  invoke_url "${DATA_VACCINE_FR}" "${usecase}"|while IFS=',' read vdate vcount vhour vsource trash; do
    if [[ $line -gt 0 ]]; then
      json="{\"vdate\":\"$(format $vdate)\",\"vhour\":\"$(format $vhour)\",\"vcount\":$(format_number $vcount),\"vsource\":\"$(format $vsource)\"}"
      push_document "${json}" '.vdate+.vhour+.vsource' "${usecase}"
    fi
    (( line++ ))
  done
  end_log "${usecase}"
}

ingest_data_world_vaccine_locations() {
  line=0
  usecase="vaccinelocations"
  start_log "${usecase}"
  invoke_url "${DATA_VACCINE_WORLD_LOCATIONS}" "${usecase}"|while IFS=',' read vplace viso vsource vurl vvaccines vdate trash; do
    if [[ $line -gt 0 ]]; then
      json="{\"vdate\":\"$(format $vdate)\",\"vplace\":\"$(format $vplace)\",\"viso\":\"$(format $viso)\",\"vvaccines\":\"$(format $vvaccines)\",\"vsource\":\"$(format $vsource)\",\"vurl\":\"$(format $vurl)\"}"
      push_document "${json}" '.vdate+.vplace+.vsource' "${usecase}"
    fi
    (( line++ ))
  done
  end_log "${usecase}"
}

ingest_data_world_vaccinations() {
  line=0
  usecase="vaccinations"
  start_log "${usecase}"
  invoke_url "${DATA_VACCINE_WORLD_VACCINATIONS}" "${usecase}"|while IFS=',' read vplace viso vdate vtotal vdaily vtotalperhundred vtotalpermillion trash; do
    if [[ $line -gt 0 ]]; then
      json="{\"vdate\":\"$(format $vdate)\",\"vplace\":\"$(format $vplace)\",\"viso\":\"$(format $viso)\",\"vtotal\":$(format_number $vtotal),\"vdaily\":$(format_number $vdaily),\"vtotalperhundred\":$(format_number $vtotalperhundred),\"vtotalpermillion\":$(format_number $vtotalpermillion)}"
      push_document "${json}" '.vdate+.vplace' "${usecase}"
    fi
    (( line++ ))
  done
  end_log "${usecase}"
}

ingest_all() {
  ingest_data
  ingest_data_fr_hostpital
  ingest_data_fr_hostpital_new
  ingest_data_fr_hostpital_age
  ingest_data_fr_hostpital_ets
  ingest_data_fr_vaccine
  ingest_data_world_vaccine_locations
  ingest_data_world_vaccinations
}

ingest_daemon() {
  usecase="${1}"
  if [[ $DAEMON_MODE == "enabled" ]]; then
    echo "Running ${usecase} as a deamon with WAIT_TIME=${WAIT_TIME}"
    while true; do
      eval "${usecase}"
      sleep "${WAIT_TIME}"
    done
  else
    echo "Running ${usecase} as a single execution"
    eval "${usecase}"
  fi
}

[[ $# -lt 1 ]] && error

if [[ $ELASTIC_URL == "changeit" || $ELASTIC_USERNAME == "changeit" || $ELASTIC_PASSWORD == "changeit" ]]; then
  echo "Error: You need to override the following variables with real values: ELASTIC_URL, ELASTIC_USERNAME and ELASTIC_PASSWORD" >&2
  exit 1
fi

if [[ ! $WAIT_TIME =~ ^[0-9]+ ]]; then
  echo "Error: You need to override WAIT_TIME with a numeric value" >&2
  exit 1
fi

options=$(getopt -o a,h,s,d -l help,debug,daemon-mode,container-mode,all,ingest-data,ingest-data-fr-hospital,ingest-data-fr-hospital-new,ingest-data-fr-hospital-age,ingest-data-fr-hospital-ets,ingest-data-fr-vaccine,ingest-data-world-vaccine-locations,ingest-data-world-vaccinations -- "$@")
set -- $options 
while true; do 
  case "$1" in 
    -h|--help) usage ; shift ;;
    -d|--debug) DEBUG_MODE="enabled" ; shift ;;
    --daemon-mode) DAEMON_MODE="enabled" ; shift ;;
    --container-mode) CONTAINER_MODE="enabled" ; shift ;;
    --ingest-data) ingest_daemon "ingest_data" ; shift ;;
    --ingest-data-fr-hospital) ingest_daemon "ingest_data_fr_hostpital" ; shift ;;
    --ingest-data-fr-hospital-new) ingest_daemon "ingest_data_fr_hostpital_new" ; shift ;;
    --ingest-data-fr-hospital-age) ingest_daemon "ingest_data_fr_hostpital_age" ; shift ;;
    --ingest-data-fr-hospital-ets) ingest_daemon "ingest_data_fr_hostpital_ets" ; shift ;;
    --ingest-data-fr-vaccine) ingest_daemon "ingest_data_fr_vaccine" ; shift ;;
    --ingest-data-world-vaccine-locations) ingest_daemon "ingest_data_world_vaccine_locations" ; shift ;;
    --ingest-data-world-vaccinations) ingest_daemon "ingest_data_world_vaccinations" ; shift ;;
    -a|--all) ingest_daemon "ingest_all" ; shift ;;
    --) shift ; break ;; 
    *) error ; shift ;;
  esac 
done
