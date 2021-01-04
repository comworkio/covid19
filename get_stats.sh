#!/usr/bin/env bash

DATA_STREAM="https://www.coronavirus-statistiques.com/corostats/openstats/open_stats_coronavirus.csv"
DATA_STREAM_FR_HOSPITAL="https://www.data.gouv.fr/fr/datasets/r/63352e38-d353-4b54-bfd1-f1b3ee1cabd7"
DATA_STREAM_FR_HOSPITAL_NEW="https://www.data.gouv.fr/fr/datasets/r/6fadff46-9efd-4c53-942a-54aca783c30c"
DATA_STREAM_FR_HOSPITAL_AGE="https://www.data.gouv.fr/fr/datasets/r/08c18e08-6780-452d-9b8c-ae244ad529b3"
DATA_STREAM_FR_HOSPITAL_ETS="https://www.data.gouv.fr/fr/datasets/r/41b9bd2a-b5b6-4271-8878-e45a8902ef00"
DATA_VACCINE_FR="https://raw.githubusercontent.com/rozierguillaume/vaccintracker/main/data.csv"
DATA_VACCINE_WORLD_LOCATIONS="https://raw.githubusercontent.com/owid/covid-19-data/master/public/data/vaccinations/locations.csv"
DATA_VACCINE_WORLD_VACCINATIONS="https://raw.githubusercontent.com/owid/covid-19-data/master/public/data/vaccinations/vaccinations.csv"
ELASTIC_URL="changeit"
ELASTIC_USERNAME="changeit"
ELASTIC_PASSWORD="changeit"
IS_DEBUG="false"

error() {
  echo "Error : invalid parameter !" >&2
  echo "Use -h to show all options" >&2
  exit 1
}

usage(){
  echo "Usage: ./getstats.sh [options]"
  echo "-h or --help: print help"
  echo "-a or --all: ingest all data"
  echo "-d or --debug: enable debug traces"
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
  date > $(get_log_file_name "${1}")
}

end_log() {
  bash -c "echo ''; date" >> $(get_log_file_name "${1}")
}

push_document() {
  json="${1}"
  jsonquery="${2}"
  usecase="${3}"
  [[ $IS_DEBUG == "true" ]] && set -x

  log_file=$(get_log_file_name "${usecase}")
  id=$(hash_id "${json}" "${jsonquery}")

  indice_url="${ELASTIC_URL}/$(get_indice_name "${usecase}" "${json}")/_doc/${id}"
  if [[ $(echo "${json}"|jq -r '.vdate') != "null" ]]; then
    curl "${indice_url}" -u "${ELASTIC_USERNAME}:${ELASTIC_PASSWORD}" -X PUT -d "${json}" -H "Content-Type: application/json" >> "${log_file}" 2>>"${log_file}"
  fi
}

ingest_data() {
  line=0
  start_log
  curl "${DATA_STREAM}" 2>>$(get_log_file_name)|while IFS=';' read vdate vcode vplace vcases vdeath vrecover vsource trash; do
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
  curl -L "${DATA_STREAM_FR_HOSPITAL}" 2>>$(get_log_file_name "${usecase}")|while IFS=';' read vplace vgender vdate vcases vrea vrad vdc trash; do
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
  curl -L "${DATA_STREAM_FR_HOSPITAL_NEW}" 2>>$(get_log_file_name "${usecase}")|while IFS=';' read vplace vdate vcases vrea vdc vrad trash; do
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
  curl -L "${DATA_STREAM_FR_HOSPITAL_AGE}" 2>>$(get_log_file_name "${usecase}")|while IFS=';' read vplace vage vdate vcases vrea vrad vdc trash; do
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
  curl -L "${DATA_STREAM_FR_HOSPITAL_ETS}" 2>>$(get_log_file_name "${usecase}")|while IFS=';' read vplace vdate vcases trash; do
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
  curl -L "${DATA_VACCINE_FR}" 2>>$(get_log_file_name "${usecase}")|while IFS=',' read vdate vcount vhour vsource trash; do
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
  curl -L "${DATA_VACCINE_WORLD_LOCATIONS}" 2>>$(get_log_file_name "${usecase}")|while IFS=',' read vplace viso vsource vurl vvaccines vdate trash; do
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
  curl -L "${DATA_VACCINE_WORLD_VACCINATIONS}" 2>>$(get_log_file_name "${usecase}")|while IFS=',' read vplace viso vdate vtotal vdaily vtotalperhundred vtotalpermillion trash; do
    if [[ $line -gt 0 ]]; then
      json="{\"vdate\":\"$(format $vdate)\",\"vplace\":\"$(format $vplace)\",\"viso\":\"$(format $viso)\",\"vtotal\":$(format_number $vtotal),\"vdaily\":$(format_number $vdaily),\"vtotalperhundred\":$(format_number $vtotalperhundred),\"vtotalpermillion\":$(format_number $vtotalpermillion)}"
      push_document "${json}" '.vdate+.vplace+.vsource' "${usecase}"
    fi
    (( line++ ))
  done
  end_log "${usecase}"
}

[[ $# -lt 1 ]] && error

options=$(getopt -o a,h,s,d -l help,debug,all,ingest-data,ingest-data-fr-hospital,ingest-data-fr-hospital-new,ingest-data-fr-hospital-age,ingest-data-fr-hospital-ets,ingest-data-fr-vaccine,ingest-data-world-vaccine-locations,ingest-data-world-vaccinations -- "$@")
set -- $options 
while true; do 
  case "$1" in 
    -h|--help) usage ; shift ;;
    -d|--debug) IS_DEBUG="true" ; shift ;;
    --ingest-data) ingest_data ; shift ;;
    --ingest-data-fr-hospital) ingest_data_fr_hostpital ; shift ;;
    --ingest-data-fr-hospital-new) ingest_data_fr_hostpital_new ; shift ;;
    --ingest-data-fr-hospital-age) ingest_data_fr_hostpital_age ; shift ;;
    --ingest-data-fr-hospital-ets) ingest_data_fr_hostpital_ets ; shift ;;
    --ingest-data-fr-vaccine) ingest_data_fr_vaccine ; shift ;;
    --ingest-data-world-vaccine-locations) ingest_data_world_vaccine_locations ; shift ;;
    --ingest-data-world-vaccinations) ingest_data_world_vaccinations ; shift ;;
    -a|--all) 
      ingest_data
      ingest_data_fr_hostpital
      ingest_data_fr_hostpital_new
      ingest_data_fr_hostpital_age
      ingest_data_fr_hostpital_ets
      ingest_data_fr_vaccine
      ingest_data_world_vaccine_locations
      ingest_data_world_vaccinations
      shift ;;
    --) shift ; break ;; 
    *) error ; shift ;;
  esac 
done
