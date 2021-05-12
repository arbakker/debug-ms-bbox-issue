#!/usr/bin/env bash
set -euo pipefail
PROGRAM_NAME=$(basename $0)

function get_request(){
    url="$1"
    http_response=$(curl -s -o /tmp/response.txt -w "%{http_code}" "$url")
    if [ $http_response != "200" ]; then
        echo "server reponded with HTTP:${http_response}" 1>&2
        echo "url: ${url}" 1>&2
        exit 1
    else
        cat /tmp/response.txt    
    fi
}

function get_next_url_gml3(){
    response_body="$1"
    regex=".*next=\"(.*)\".*"
    line_match=$(echo "$response_body" | egrep -e $regex)
    if [[ $line_match =~ $regex ]];then
       echo "${BASH_REMATCH[1]}" | sed 's/\&amp\;/\&/g' 
       return
    fi
    echo ""
}

function get_next_url_json(){
    start_url="$1"
    count="$2"
    echo "${start_url}&STARTINDEX=${count}"
}

function count_features(){
    response_body="$1"
    ft_name="$2"
    ogrinfo /vsistdin/ $ft_name -so<<<"$response_body" | grep "Feature Count:" | cut -d" " -f3
}

if test "$#" -lt 1; then
   echo "usage: $PROGRAM_NAME <bbox> <output-format>"
   exit 1
fi

BBOX="$1"
OUTPUT_FORMAT="$2"

FT_NAME="beheer_leiding"
START_URL="http://localhost?SERVICE=WFS&version=2.0.0&service=wfs&request=Getfeature&bbox=${BBOX}&outputformat=${OUTPUT_FORMAT}&srsname=EPSG%3A28992&typename=gwsw%3A${FT_NAME}" 
NEXT_URL="$START_URL"
COUNT=0
while true; do
    if [[ -z "$NEXT_URL" ]];then
        break
    fi
    RESPONSE_BODY=$(get_request "$NEXT_URL")
    current_count=$(count_features "$RESPONSE_BODY" "$FT_NAME")
    if [[ $current_count -eq 0 ]];then
        break
    fi
    echo "current number of features: $current_count"
    COUNT=$(bc<<<"$COUNT+$current_count")
    if grep -q "gml3"<<<$START_URL; then
        NEXT_URL=$(get_next_url_gml3 "$RESPONSE_BODY")
    elif  grep -q "application/json"<<<$START_URL; then
        NEXT_URL=$(get_next_url_json "$START_URL" "$COUNT")
    else
        echo "unsupported output format in url. Support formats: gml3, application/json"
    fi
    echo "next_url: \"$NEXT_URL\""
done

echo "total number of features: $COUNT"
