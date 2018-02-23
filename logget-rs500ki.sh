#! /bin/sh

export LANG=C
export PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin

BASEDIR=$(cd "$(dirname "$0")" && pwd)
CONFDIR=${BASEDIR}

# shellcheck source=./rs500ki.conf
. ${CONFDIR}/rs500ki.conf

HGW_URLBASE=http://${HGW_ADDR}/ntt/information
HGW_V4LOG=v4SecurityLog
HGW_V6LOG=v6SecurityLog

SNAPDIR=${BASEDIR}
V4LOG_SNAPFILE=rs500ki-v4.log
V6LOG_SNAPFILE=rs500ki-v6.log
TMPFILE=rs500ki.tmp

vers="v4 v6"

LATEST_IN_OLD=""

rm -f ${SNAPDIR}/${TMPFILE}

for v in ${vers}; do
    case ${v} in
        "v4")
            SNAPFILE=${V4LOG_SNAPFILE}
            LOGURL=${HGW_V4LOG} ;;
        "v6")
            SNAPFILE=${V6LOG_SNAPFILE}
            LOGURL=${HGW_V6LOG} ;;
    esac

    if [ -f ${SNAPDIR}/${SNAPFILE} ]; then
        mv -f ${SNAPDIR}/${SNAPFILE} ${SNAPDIR}/${SNAPFILE}.old
        LATEST_IN_OLD=$(head -n 1 ${SNAPDIR}/${SNAPFILE}.old)
    fi

    curl --silent \
         --show-error \
         --user ${HGW_USER}:${HGW_PASSWD} ${HGW_URLBASE}/${LOGURL} | \
        tail -n +3 | \
        sed -e '$d'| \
        sed -e 's/^ *[0-9]*\. //' | \
        sed -e 's///' > ${SNAPDIR}/${SNAPFILE}

    if [ -z "${LATEST_IN_OLD}" ]; then
        cat ${SNAPDIR}/${SNAPFILE} >> ${SNAPDIR}/${TMPFILE}
    else
        LINE_IN_CUR=$(grep -n "${LATEST_IN_OLD}" ${SNAPDIR}/${SNAPFILE})
        if [ -n "${LINE_IN_CUR}" ]; then
            lnum=$(echo "${LINE_IN_CUR}" | \
                       awk -F: '{print $1}')
            if [ ${lnum} -gt 1 ]; then
                head -n $((lnum-1)) ${SNAPDIR}/${SNAPFILE} >> ${SNAPDIR}/${TMPFILE}
            fi
        fi
    fi
done

if [ -f ${SNAPDIR}/${TMPFILE} ]; then
    sort ${SNAPDIR}/${TMPFILE} | \
        logger -t hgw -p ${SYSLOG_FACILITY}.${SYSLOG_LEVEL}
fi

rm -f ${SNAPDIR}/${TMPFILE}

exit 0
