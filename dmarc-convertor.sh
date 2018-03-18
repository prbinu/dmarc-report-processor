#!/bin/env bash
# Copyright (c) 2014, Yahoo! Inc.
# Copyrights licensed under the New BSD License. See the
# accompanying LICENSE.txt file for terms.
#
# Author Binu P. Ramakrishnan
# Created 09/18/2014
#
# This script does 3 things:
# 1. Pull dmarc report attachments from yahoo mail 
# 2. Unzip these report files to a separate folder
# 3. Convert dmarc xml files to line oriented format for splunk
#

ROOT='/usr/local/dmarc-report-processor'
DMARC_ROOT="${ROOT}/var"
ATTACH="${DMARC_ROOT}/attach_raw"
XML="${DMARC_ROOT}/dmarc_xml"
DMARC_SPLUNK="${DMARC_ROOT}/dmarc_splunk"

os=`uname`
ydate=`date -d "yesterday 00:00 " '+%d-%h-%Y'`
#ydate=`date -d "1 week ago 13:00 " '+%d-%h-%Y'`
if [ "$os" == "Darwin" ]
then
  ydate=`date -v-1d +%d-%h-%Y`
fi

tdate=`date '+%d-%h-%Y'`

d_host=""
d_port=993
d_user=""
d_pwd=""
d_cert=""

dmarc_help() {
  cat << EOF
  Usage: ${0##*/} -u user_emailid -s imapserver -c cacertfile [-p port] [-P pwdfile] [-h] 
  Options:
    -u   User email id
    -P   File that contains user password. Default: The user will be 
         prompted to provide password if you leave this option.
         WARNING: The file should be with permission
         0400 or 0440 (ie should NOT be world readable)
    -s   IMAP server name
    -p   IMAP port number. Default: 993
    -c   CA certificate file (eg. cacert.pem), used to validate certificates
         passed from IMAP server
    -h   Help

  Example:
    ${0##*/} -u dmarc@example.com -P ./pwd -s imap.example.com -p 993 -c ./cacert.pem

EOF
}

OPTIND=1
while getopts "hs:p:u:P:c:" opt; do
case "$opt" in
  h)
    dmarc_help
    exit 0
    ;;
  s) d_host=$OPTARG
    ;;
  p) d_port=$OPTARG
    ;;
  u) d_user=$OPTARG
    ;;
  P) d_pwd=$OPTARG
    ;;
  c) d_cert=$OPTARG
    ;;
  '?')
     dmarc_help >&2
     exit 1
     ;;
  esac
done

shift "$((OPTIND-1))" # Shift off the options and optional --.

if [ -z "${d_user}" ]
then
  echo "Error: User name not provided (-u)" >&2
  exit 1
fi

# create directory if it doesn't exists. Ignore error if exists
mkdir -m 0755 ${DMARC_ROOT} 2> /dev/null
mkdir -m 0755 ${ATTACH} 2> /dev/null
mkdir -m 0755 ${XML} 2> /dev/null
mkdir -m 0755 ${DMARC_SPLUNK} 2> /dev/null
mkdir -m 0755 ${ATTACH}/${ydate}
if [ "$?" -ne "0" ]
then
  rm -rf "${ATTACH}/${ydate}.old" 2> /dev/null
  mv "${ATTACH}/${ydate}" "${ATTACH}/${ydate}.old"
  mkdir -m 0755 "${ATTACH}/${ydate}"
fi


# imap search criteria. Defined here: http://tools.ietf.org/html/rfc3501.html#page-49
d_search="SINCE \"${ydate}\" BEFORE \"${tdate}\""
#d_search="SINCE \"11-Sep-2014\" BEFORE \"12-Sep-2014\""

#1
echo "Step 1: Fetch dmarc reports from mailbox"
echo "----------------------------------------"
${ROOT}/bin/imap-client.py --attachmentsonly -s "${d_host}" -c "${d_cert}" --port "${d_port}"  -u "${d_user}" -o ${ATTACH}/${ydate} -f ${RUAFOLDER} --pwdfile "${d_pwd}" -S "${d_search}"
if [ "$?" -ne "0" ]
then
  echo "Error: imap-client mail attachment fetch failed; exiting ..."
  exit 1
fi

#2
shopt -s nullglob
files=( "${ATTACH}/${ydate}"/* )
if [ "${#files[@]}" -eq "0" ]
then
        echo "No new reports found. Exiting ..."
        exit 0
fi

echo "Step 2: Unzipping files"
echo "-----------------------"
mkdir "${XML}/${ydate}"
rm -rf "${XML}/${ydate}/*" 2> /dev/null
for f in "${files[@]}"; do
  echo "$f"
  extn="${f##*.}"
  if [ "$extn" == "zip" ]
  then
    # remove just in case
    rm -f ${XML}/${ydate}/${f} 2>/dev/null
    unzip $f -d "${XML}/${ydate}"
  elif [ "$extn" == "gz" ]
  then
    fname=$(basename $f)
    gunzip -c $f > "${XML}/${ydate}/${fname%.*}"
  else
    echo "File extension not supported: ${f}; skipping ..."
  fi
done

#3
echo "Step 3: Converting xml files"
echo "----------------------------"
mkdir "${DMARC_SPLUNK}/${ydate}"
rm -rf "${DMARC_SPLUNK}/${ydate}/*" 2> /dev/null
for f in "${XML}/${ydate}"/*; do
  fname=$(basename $f)
  fname2=$(printf '%q' "${f}")
  ${ROOT}/bin/dmarc-parser.py ${f} > "${DMARC_SPLUNK}/${ydate}/${fname%.*}.log"
  if [ "$?" -ne "0" ]
  then
    echo "Error: Splunk conversion failed; File: ${f}"
  fi
done

rm "${DMARC_SPLUNK}/latest" 2> /dev/null
ln -s "${DMARC_SPLUNK}/${ydate}" "${DMARC_SPLUNK}/latest"

#remove folders that are more than 5 days old
find "${ATTACH}/${ydate}" -type d -ctime +5 2>/dev/null | xargs rm -rf
find "${XML}/${ydate}" -type d -ctime +5 2>/dev/null | xargs rm -rf
find "${DMARC_SPLUNK}/${ydate}" -type d -ctime +5 2>/dev/null | xargs rm -rf
find "${ROOT}/logs/dmarc-report-processor" -type d -ctime +5 2>/dev/null | xargs rm -rf


