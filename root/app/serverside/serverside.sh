#!/usr/bin/with-contenv bash
# shellcheck shell=bash
# Copyright (c) 2020 ; MrDoob
# All rights reserved.
# SERVER SIDE ACTION 
##############################
####
function log() {
    echo "[Server Side] ${1}"
}
###execute part 
SVLOG="serverside"
RCLONEDOCKER="/config/rclone-docker.conf"
LOGFILE="/config/logs/${SVLOG}.log"
truncate -s 0 /config/logs/${SVLOG}.log
DISCORD="/config/discord/${SVLOG}.discord"
DISCORD_WEBHOOK_URL=${DISCORD_WEBHOOK_URL}
SERVERSIDEDRIVE=${SERVERSIDEDRIVE:-null}
SERVERSIDE=${SERVERSIDE}
REMOTEDRIVE=${REMOTEDRIVE:-null}
SERVERSIDEMINAGE=${SERVERSIDEMINAGE:-null}
SERVERSIDECHECK=$(cat ${RCLONEDOCKER} | awk '$1 == "server_side_across_configs" {print $3}' | wc -l)
rm -rf /config/json/serverside.lck
#####
if [[ "${SERVERSIDECHECK}" -lt "2" ]]; then
   log ">>>> [ WARNING ] Server-Side failed [ WARNING ] <<<<<"
   log ">>>> [ WARNING ] check your rclone-docker.conf [ WARNING ] <<<<<"
   sleep 10
   touch /etc/services.d/serverside/down 
   exit 0
fi
if grep -q "\[tcrypt\]" ${RCLONEDOCKER} && grep -q "\[gcrypt\]" ${RCLONEDOCKER}; then
   rccommand1=$(rclone reveal $(cat ${RCLONEDOCKER} | awk '$1 == "password" {print $3}' | head -n 1 | tail -n 1))
   rccommand2=$(rclone reveal $(cat ${RCLONEDOCKER} | awk '$1 == "password" {print $3}' | head -n 2 | tail -n 1))
   rccommand3=$(rclone reveal $(cat ${RCLONEDOCKER} | awk '$1 == "password2" {print $3}' | head -n 1 | tail -n 1))
   rccommand4=$(rclone reveal $(cat ${RCLONEDOCKER} | awk '$1 == "password2" {print $3}' | head -n 2 | tail -n 1))
   if [[ "${rccommand1}" != "${rccommand2}" && "${rccommand3}" != "${rccommand4}" ]]; then
      log ">>>>> [ WARNING ] Server_side can't be used <<<<< [ WARNING ]"
      log ">>>>> [ WARNING ] TCrypt and GCrypt dont used the same password <<<<< [ WARNING ]"
      sleep 10
      touch /etc/services.d/serverside/down
      exit 0
   fi
fi
#####
if [ "${SERVERSIDEMINAGE}" != 'null' ] || [ "${SERVERSIDEMINAGE}" == 'false' ]; then
   SERVERSIDEMINAGE=${SERVERSIDEMINAGE}
   SERVERSIDEAGE="--min-age ${SERVERSIDEMINAGE}"
else
   SERVERSIDEAGE="--min-age 48h"
fi
#####
if [[ "${REMOTEDRIVE}" == "null" ]]; then
   if grep -q "\[tdrive\]" ${RCLONEDOCKER} ; then
      REMOTEDRIVE=tdrive
   else
      sleep 10
      touch /etc/services.d/serverside/down
      exit 0
   fi
fi
#####
if [[ "${SERVERSIDEDRIVE}" == "null" ]]; then
   if grep -q "\[gdrive\]" ${RCLONEDOCKER} ; then
      SERVERSIDEDRIVE=gdrive
   else
      sleep 10
      touch /etc/services.d/serverside/down
      exit 0
   fi
fi
if [[ "${SERVERSIDEDAY}" == 'null' ]]; then
   SERVERSIDEDAY=Sunday
 else
   SERVERSIDEDAY=${SERVERSIDEDAY}
fi
################
## SERVERSIDE ##
################
while true; do
   if [[ $(date '+%A') == "${SERVERSIDEDAY}" ]]; then
   SERVERSIDE=${SERVERSIDE}
   lock="/config/json/serverside.lck"
   RCLONEDOCKER="/config/rclone-docker.conf"
   REMOTEDRIVE=${REMOTEDRIVE:-null}
   SERVERSIDEMINAGE=${SERVERSIDEMINAGE:-null}
   SERVERSIDEDRIVE=${SERVERSIDEDRIVE}
   LOGFILE="/config/logs/${SVLOG}.log"
   echo "lock" >"${lock}"
   echo "lock" >"${DISCORD}"
   STARTTIME=$(date +%s)
   touch "${LOGFILE}"
   log "Starting Server-Side move from ${REMOTEDRIVE} to ${SERVERSIDEDRIVE}"
   rclone moveto --checkers 4 --transfers 2 \
                 --config=${RCLONEDOCKER} --user-agent="SomeLegitUserAgent" \
                 --log-file="${LOGFILE}" --log-level INFO --stats 2s \
                 --no-traverse ${SERVERSIDEAGE} \
                 "${REMOTEDRIVE}:" "${SERVERSIDEDRIVE}:"

   log "Starting Server-Side dedupe for ${REMOTEDRIVE}"
   rclone dedupe --dedupe-mode largest user-agent="SomeLegitUserAgent" \
                 --verbose=1 --fast-list --retries 3 --no-update-modtime \
                 --config=${RCLONEDOCKER} "${REMOTEDRIVE}:"

   log "Starting Server-Side dedupe for "${SERVERSIDEDRIVE}"
   rclone dedupe --dedupe-mode largest user-agent="SomeLegitUserAgent" \
                 --verbose=1 --fast-list --retries 3 --no-update-modtime \               
                 --config=${RCLONEDOCKER} "${SERVERSIDEDRIVE}:"

   log "Starting Server-Side cleanup empty folders on ${REMOTEDRIVE}"
   rclone rmdirs --checkers 4 --config=${RCLONEDOCKER} --user-agent="SomeLegitUserAgent" \
                 --leave-root --no-traverse "${REMOTEDRIVE}:"

   rclone cleanup --config=${RCLONEDOCKER} --user-agent="SomeLegitUserAgent" "${REMOTEDRIVE}:"
   rclone cleanup --config=${RCLONEDOCKER} --user-agent="SomeLegitUserAgent" "${SERVERSIDEDRIVE}:"

   ENDTIME=$(date +%s)
   if [ ${DISCORD_WEBHOOK_URL} != 'null' ]; then
      TITEL="Server-Side Move"
      DISCORD_ICON_OVERRIDE=${DISCORD_ICON_OVERRIDE}              
      DISCORD_NAME_OVERRIDE=${DISCORD_NAME_OVERRIDE}
      TIME="$((count=${ENDTIME}-${STARTTIME}))"
      duration="$(($TIME / 60)) minutes and $(($TIME % 60)) seconds elapsed."
      # shellcheck disable=SC2006 
      echo "Finished Server-Side move from ${REMOTEDRIVE} to ${SERVERSIDEDRIVE} \nTime : ${duration}" >"${DISCORD}"
      msg_content=$(cat "${DISCORD}")
      curl -H "Content-Type: application/json" -X POST -d "{\"username\": \"${DISCORD_NAME_OVERRIDE}\", \"avatar_url\": \"${DISCORD_ICON_OVERRIDE}\", \"embeds\": [{ \"title\": \"${TITEL}\", \"description\": \"$msg_content\" }]}" $DISCORD_WEBHOOK_URL
      rm -rf "${DISCORD}"
      rm -rf "${lock}"
   else
      log "Finished Server-Side move from ${REMOTEDRIVE} to ${SERVERSIDEDRIVE}"
      rm -rf "${lock}"
   fi
   sleep $(($(date -f - +%s- <<< $'tomorrow 00:30\nnow')0))
   else
     sleep $(($(date -f - +%s- <<< $'tomorrow 00:30\nnow')0))
   fi
done
