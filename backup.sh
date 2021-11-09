#!/bin/bash

# Dependencies: lftp, zip, mail

################################
#### Script settings

# Temporary folder path eg. "/root/tmp/backups"
TMP_FOLDER=""

# Domain files path eg. "/var/www/html"
LOCAL_WWW_FOLDER=""

# Domain to backup eg. "example.com"
DOMAIN=""

# DB to backup settings
DB_USER=""
DB_PASS=""
DB_NAME=""

# Settings of remote FTP host to store backups
FTP_USER=""
FTP_PASS=""
FTP_HOST=""

# Notification email address
MAIL_ALERT="you@exapmle.com"

# Days to keep old backups on remote FTP
DAYS_OLD="7"

###################################
MYSQL_FOLDER="${TMP_FOLDER}/MYSQL.TMP"
WWW_FOLDER="${TMP_FOLDER}/WWW.TMP"



alert()
{
        echo "Error executing step ${1}" | mail -s "error from backup" ${MAIL_ALERT}
        exit 1
}

case "${1}" in
start)
    # PERFORM THE ACTUAL BACKUP (CALLED BY CRON)
	echo "Create mysql backup folder ..."
    mkdir -p ${MYSQL_FOLDER}
	echo "Create files backup folder ..."
    mkdir -p ${WWW_FOLDER}
	echo "Create mysql database dump ..."
    cd ${MYSQL_FOLDER}
	mysqldump --opt -u${DB_USER} -p${DB_PASS} ${DB_NAME} > ${DB_NAME}.sql || alert 1 
	zip -9 ${DB_NAME}.sql.zip ${DB_NAME}.sql || alert 2
	rm -f ${DB_NAME}.sql

	# BACKUP FILES
    cd ${LOCAL_WWW_FOLDER}
	echo "Compress files "
	zip -r "${WWW_FOLDER}/${DOMAIN}.zip" "$DOMAIN" || alert 3

	# CREATE DAILY BACKUP FILE (WEB FILES + DATABSE)
    cd ${TMP_FOLDER}
    BACKUP_FILENAME="backup-${DOMAIN}-"`date +%F`".zip"
	echo "Make daily backup file ... ${BACKUP_FILENAME}"
    zip -r1  ${BACKUP_FILENAME} WWW.TMP MYSQL.TMP || alert 4
    rm -rf ${MYSQL_FOLDER} ${WWW_FOLDER}

    # CHECK IF THERE IS A BACKUP WITH THE SAME NAME AND REMOVE IT
    FOUND=$(lftp -e 'set ftp:ssl-force; set ssl:verify-certificate no; cd backup; cls --sort="date"; exit;' -u ${FTP_USER},${FTP_PASS} ${FTP_HOST} 2> /dev/null | grep "${BACKUP_FILENAME}")
        if [ -n "${FOUND}" ]
        then
                lftp -e "set ftp:ssl-force; set ssl:verify-certificate no; cd backup; rm -f ${BACKUP_FILENAME}; exit;" -u ${FTP_USER},${FTP_PASS} ${FTP_HOST} || alert 5
        fi

        # FTP TRANSER
        lftp -e "set ftp:ssl-force; set ssl:verify-certificate no; cd backup; put ${BACKUP_FILENAME}; exit;" -u ${FTP_USER},${FTP_PASS} ${FTP_HOST} || alert 6

        # REMOVE OLD BACKUPS
        FILES=$(lftp -e 'set ftp:ssl-force; set ssl:verify-certificate no; cd backup; cls --sort="date"; exit;' -u ${FTP_USER},${FTP_PASS} ${FTP_HOST}) || alert 7
        while [ $(echo "${FILES}" | grep -E "^[0-9]{4}-[0-9]{2}-[0-9]{2}.tar" | wc -l) -gt ${DAYS_OLD} ]
        do
                FILE_TO_REMOVE=$(echo "${FILES}" | grep -E "^[0-9]{4}-[0-9]{2}-[0-9]{2}.tar" | sort | head -n1)
                echo"Removing backups old backups: ${FILE_TO_REMOVE}" 
		lftp -e "set ftp:ssl-force; set ssl:verify-certificate no; cd backup; rm -f ${FILE_TO_REMOVE}; exit;" -u ${FTP_USER},${FTP_PASS} ${FTP_HOST} || alert 8
                FILES=$(lftp -e 'cd backup; cls --sort="date"; exit;' -u ${FTP_USER},${FTP_PASS} ${FTP_HOST}) || alert 7
        done
        ;;
list)
        # RETURN THE LIST OF BACKUPS
    	echo "Listing existing backups on remote FTP..."
        lftp -e 'set ftp:ssl-force; set ssl:verify-certificate no; cd backup; cls --sort="date"; exit;' -u ${FTP_USER},${FTP_PASS} ${FTP_HOST} 2> /dev/null
        ;;
get)
        # GET A SELECTED BACKUP
        BACKUP_FILE="${2}"
        if [ -z "${BACKUP_FILE}" ]
        then
                echo "Error: specify a backup file to download"
                echo "for example: ${0} get FILE_NAME"
                exit 1
        fi
        FOUND=$(lftp -e 'set ftp:ssl-force; set ssl:verify-certificate no; cd backup; cls --sort="date"; exit;' -u ${FTP_USER},${FTP_PASS} ${FTP_HOST} 2> /dev/null | grep "${BACKUP_FILE}")
        if [ -z "${FOUND}" ]
        then
                echo "Error: the file specified does not exist"
                exit 1
        fi
        lftp -e "set ftp:ssl-force; set ssl:verify-certificate no; cd backup; get ${BACKUP_FILE}; exit;" -u ${FTP_USER},${FTP_PASS} ${FTP_HOST}
        if [ ! "${?}" = "0" ]
        then
                echo "Error downloading file ${BACKUP_FILE} from backup storage server!"
                exit 1
        else
                echo "File downloaded correctly"
        fi
        ;;
*)
        # USAGE
        echo "Usage: ${0} <start|list|get [FILE_NAME]>"
        echo "-----------------------------------------------"
        echo "To start backup: ${0} start"
        echo "To list remote backups: ${0} list"
        echo "To download a specific backup: ${0} get FILE_NAME"
        exit 1
        ;;
esac

exit 0
