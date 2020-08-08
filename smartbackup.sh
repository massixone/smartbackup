#/bin/bash -x
#
# -*- coding:utf-8, indent=space, tabstop=4 -*-
#
#    smartdbbackup is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
#   @package    smartdbbackup
#   @modle      Mail program
#   @author     Massimo Di Primio   massimo@diprimio.com
#   @license    GNU General Public License version 3, or later
#
# 
#  ____                       _     ____             _                
# / ___| _ __ ___   __ _ _ __| |_  | __ )  __ _  ___| | ___   _ _ __  
# \___ \| '_ ` _ \ / _` | '__| __| |  _ \ / _` |/ __| |/ / | | | '_ \ 
#  ___) | | | | | | (_| | |  | |_  | |_) | (_| | (__|   <| |_| | |_) |
# |____/|_| |_| |_|\__,_|_|   \__| |____/ \__,_|\___|_|\_\\__,_| .__/ 
#                                                              |_|    
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   P R E A M B L E
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

declare SDBU_APP_VERSION="1.0.3"

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   C O N F I G
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

typeset -i SDBU_ERROR_BCKUP=0  # Error flag for Backup commands 
typeset -i SDBU_ERROR_TRANF=0  # Error flag for Transfer commands

# Define Error constant
declare -i SDBU_C_ERROR_BACKUP=0x01     # Error while executing database backup
declare -i SDBU_C_ERROR_COMPRS=0x02     # Error while compressing backup file
declare -i SDBU_C_ERROR_ROTATE=0x03     # Error while rotating file
declare -i SDBU_C_ERROR_TRASFR=0x04     # Error while transferring file

# Define Global error container
declare -i SDBU_G_ERROR=0               # Global continer for error detection


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   F U N C T I O N S
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# function basename ()
# replacement for 'basename' linux command
# @ fully qualified file name
function basename () {
    TMPARG=$1
    echo ${TMPARG##*/}
}

# function dirname()
# replacement for 'dirname' linux command
function dirname() {
    TMPARG=$1
    echo ${TMPARG%/*}
}

# function do_create_pid_file ()
# Create 'pid' file containing this instance process id (pid), to prevent multiple
# instance of this program to run at the same time.
# Checks is a pid file already exists and removes if the corresponding process (pid)
# does not exist or it is not associated with ${APP_NAME}
# @1 string     fully qualified path name of the pid file
function do_create_pid_file () {

    if [ $# -le 0 ];then
        do_echo "${FUNCNAME}(). ERROR! No pid file specified!"; 
        exit -1 #do_exit
    fi
    PF=$1
    if [ -e ${PF} ]; then
        do_echo "${FUNCNAME}(). WRNING! Pid file [${PF}] already exists."; do_exit
        do_exit
        # Following part will be implemented soon
        # This is to check if the PID found in the Pid file correspond to an instance of this program.
        # If NOT: We can proceed creating the pid file (the file is a very old occurence)
        # If EXISTS: We cannot proceed, since the PID found is really an instance of this program
        do_echo "Now checking ${APP_NAME}..."
        OLDPID=$(cat ${PF})
        ps -ef | grep -v grep | grep ${OLDPID} | grep ${APP_NAME} > /dev/null 2>&1
        RC=$?
        if [ ${RC} -ne 0 ]; then
            rm -f ${PF}                 # process not found; go ahead.
            echo $$ > ${PF}             # write pid of this process in pid file
            echo "${FUNCNAME}().Current PID file is [${PF}]"
        else
            do_echo "\nAnother instance of this program is already running. Exiting."           
            exit -1 #do_exit
        fi
    else
        echo $$ > ${PF}
    fi 

#echo $$ > ${SDBU_PIDFILE}
}

# function do_usage ()
# Shows usage
# @ No arguments
function do_usage () {
    
    echo -en "\n***** $(basename $0)  - Version:  ${SDBU_APP_VERSION}
        usage:.\n
        -h | --help         show this message
        -c config_name      Use the specified configuration file       
        -i                  Interactive. Show log messages while running
        -q                  Quiet. Do not show log messages while running
        "

}

# ------------------------------------------------------------
# do_echo () 
# @1  string    the message to be shown on th screen
# Writes (actually echo) the given string(s) ONLY if running
# interactively (i.e. attached terminal exists and it is
# coherent: not run by cron).
# ------------------------------------------------------------
function do_echo () {
    #if [ $TERM != 'dumb' ];then
    #      [ ${DBG_FLG} -ne 0 ] && echo -e "[`/usr/bin/basename $0`] $*"
    #fi
    echo -en "[$(basename $0)] $(date "+%Y-%m-%d %H:%M:%S") $*\n"
}

# do_exit
# Does all necessary operations to terminate the program
# @ No rguments
function do_exit () {
    do_echo "${FUNCNAME}() Program is terminating"
    kill $$
}

# function sdbu_send_email ()
# Send an email to the indicated receipient, including in the body the content of the selected file
# @1    string  The email receipient
# @2    string  The file name containing the content
# @3    string  (optional) The email 'Subject'
# @4    [for future versions] string  (optional) The 'From' name
# @5    [for future versions] array   (optional) An array of string containing a list of file to attach
function sdbu_send_email () {
    # Grab receipient
    #echo "[DEBUG] Count: $# Args $*"
    if [ $# -le 0 ]; then
        do_echo "${FUNCNAME}() Error! No receipient specified"; return 1   #exit -1
    fi

    TMP_RCPT=$1; shift
    # Grab email content
    if [ $# -le 0 ]; then
        do_echo "${FUNCNAME}() Error! No file content specified"; return 1 #exit -1
    else
    TMP_FBODY=$1; shift 1
    fi

    # Grab email subjet
    if [ $# -le 0 ]; then
        do_echo "${FUNCNAME}() Warning! No email 'Subject' specified"
        TMP_ESUBJ="No subject"
    else
        TMP_ESUBJ=$1; shift 1
    fi

    # Grab email 'From Name'
    if [ $# -le 0 ]; then
        do_echo "${FUNCNAME}() Warning! No email 'From' name specified"
    else
        TMP_FROM=$1; shift 1
    fi

    # Grab Attachment array
    if [ $# -le 0 ]; then
        do_echo "${FUNCNAME}() Warning! No attachment files specified"
    else
        TMP_ATTCH=$1; shift 1
    fi
    #
    # Verify email content (file) exists and is readable
    do_echo "${FUNCNAME}() Building up the email to be sent."
    if [ ! -e ${TMP_FBODY} ]; then
        do_echo "${FUNCNAME}() Error! Content file does not exist."
        return 1   #exit -1
    fi
    #
    # Prepare command line chunk for attachments
    for f in ${TMP_ATTCH}; do
        TMP_CMDA="${TMP_CMDA} -a ${f}"       
    done
    #
    # Send out the email   
    do_echo "${FUNCNAME}() Sending email as follows:
        Content file    '${TMP_FBODY}'
        Email From      '<${USER}> ${TMP_FROM}'
        Email To        '${TMP_RCPT}'
        Email Subject   '${TMP_ESUBJ}'
        Attach files    '${TMP_CMDA}'
        "
    #cat ${TMP_FBODY} | /bin/mail -s "${TMP_ESUBJ}" ${TMP_CMDA} "${TMP_RCPT}"
    /bin/mail -s "${TMP_ESUBJ}" ${TMP_CMDA} "${TMP_RCPT}" < ${TMP_FBODY}
    RC=$?
    if [ ${RC} -ne 0 ]; then
        do_echo "${FUNCNAME}() Error! Email was not sent due to error [${RC}]"
        return 1   #exit -1
    fi
    do_echo "${FUNCNAME}() Email was sent successfully"
    do_echo "${FUNCNAME}() Please check out the email queue."
}

# function rotate_file()
# @1  string    File name to be rotated
# @2  integer   Number og older copies of the file to be kept
function rotate_file () {
    #echo $#

    typeset -i ROTATE_N                             # Define the integer rotate counter
    # [DEBUG] let ROTATE_N=${SDBU_ROTATE_BACKUPS}  # Grab default vallue, just in case
    [ $# -lt 1 ] && return 1   #exit -1;                        # grab file name
    ROTATE_F=$1; shift
    [ $# -lt 1 ] && return 1   #exit -1                         # grab rotation counter
    ROTATE_N=$1
    if [ ${ROTATE_N} -le 0 ]; then
        do_echo "${FUNCNAME}() Error! No rotation is performed due to rotation number set to ${ROTATE_N})"
        return 0   #exit 0              # Avoid rotation attempt when ROTATE_N is not meaningful    
    fi

    do_echo "${FUNCNAME}() Rotating file '${ROTATE_F}', keeping latest [${ROTATE_N}] files"
    ((ROTATE_N=ROTATE_N-1))
    while [ ${ROTATE_N} -ge 1 ]; do
        TMP_FILE_SRC="${ROTATE_F}.-$((${ROTATE_N}+0))"
        TMP_FILE_DST="${ROTATE_F}.-$((${ROTATE_N}+1))"
        # [DEBUG] eecho "SRC: ${TMP_FILE_SRC} - DST: ${TMP_FILE_DST}"
        [ -a ${TMP_FILE_SRC} ] && mv ${TMP_FILE_SRC} ${TMP_FILE_DST}
        # [DEBUG] eecho "ROTATE_N: $ROTATE_N"; read -p "Type enter to continue" $a
        ((ROTATE_N=ROTATE_N-1))
    done

    # [DEBUG] echo "xROTATE_N: $ROTATE_N"; read -p "xType enter to continue" $a
    # [DEBUG] echo "xSRC: ${ROTATE_F} - xDST: ${TMP_FILE_SRC}"
    # [TEST]  [ -a ${ROTATE_F} ] && mv ${ROTATE_F} ${TMP_FILE_SRC}   # rotate the most recent file
    [ -a ${ROTATE_F} ] && (cp -fp ${ROTATE_F} ${TMP_FILE_SRC}; cp -f /dev/null ${ROTATE_F})   # rotate the most recent file
}

# function do_db_backup ()
# Executes database backup depending on database type
# @1    String  File name for the backup file
function do_db_backup () {
    if [ $# -le 0 ]; then
        do_echo "${FUNCNAME}() Error! No backup file specified. Terminating..."
        return 1   #exit -1                                 # Return error on no backup file
    fi
    TMP_FILE_BCK=$1
    TMP_FILE_LOG=${TMP_FILE_BCK}.err
    do_echo "${FUNCNAME}() Performming backup:
        DB Name:             '${SDBU_DB_NAME}',
        DB Host:             '${SDBU_DB_HOST}',
        DB User:             '${SDBU_BD_USER}',
        Backup dumb file is: '${TMP_FILE_BCK}',
        Log file is:         '${TMP_FILE_LOG}'."
    case ${SDBU_DB_TYPE} in
        'postgresql')
            # Remember that password for postgresql DB can be provided bu ~/.pgpass and may depend on 
            # postgresql configuration file: /var/lib/pgsql/data/pg_hba.conf
            do_echo "${FUNCNAME}() Launching PostgreSQL backup via command: 'pg_dump'..."
            echo ${SDBU_DB_PASS} | \
            do_echo "DB Dump as: pg_dump -h ${SDBU_DB_HOST} -U ${SDBU_BD_USER} -p ${SDBU_DB_PORT} ${SDBU_DB_NAME} > ${TMP_FILE_BCK} 2> ${TMP_FILE_LOG}"
            /usr/bin/pg_dump -h ${SDBU_DB_HOST} -U ${SDBU_BD_USER} -p ${SDBU_DB_PORT} ${SDBU_DB_NAME} > ${TMP_FILE_BCK} 2> ${TMP_FILE_LOG}
            ;;
        'mysql')
            do_echo "${FUNCNAME}() Launching MySQL backup via command: 'mysqldump'..."
            /usr/bin/mysqldump -h ${SDBU_DB_HOST} -u ${SDBU_BD_USER} -P ${SDBU_DB_PORT} -p${SDBU_DB_PASS} ${SDBU_DB_NAME} > ${TMP_FILE_BCK} 2> ${TMP_FILE_LOG}
            ;;
        'mariadb')
            do_echo "${FUNCNAME}() Launching MariaDB backup via command: 'mysqldump'..."
            /usr/bin/mysqldump -h ${SDBU_DB_HOST} -u ${SDBU_BD_USER} -P ${SDBU_DB_PORT} -p${SDBU_DB_PASS} ${SDBU_DB_NAME} > ${TMP_FILE_BCK} 2> ${TMP_FILE_LOG}
            ;;
    esac
    RC=$?
    if [ ${RC} -eq 0 ];then
        do_echo "${FUNCNAME}() Latest backup program completed successfully [${RC}]"
    else
        do_echo "${FUNCNAME}() Error! Latest backup program terminated with error [${RC}]"
        return 1   #exit -1
    fi
}

# function do_file_compress ()
# Compress a given file name using 'gzip' with the best possible compression (slowest)
# @1    string  the file name to be compressed
function do_file_compress () {
    if [ $# -le 0 ]; then
        do_echo "${FUNCNAME}() Error! No file name was specified for compression. Terminating..."
        return-1
    fi
    TMP_FILE_NAME=$1
    do_echo "${FUNCNAME}() Compressing file: '${TMP_FILE_NAME}'..."
    gzip -f -9 ${TMP_FILE_NAME}
    if [ $? -ne 0 ];then
        do_echo "${FUNCNAME}() Error! Last file compression failed on file: '${TMP_FILE_NAME}'"
       do_exit -1
    fi
    do_echo "${FUNCNAME}() File compression completed successfully on file: '${TMP_FILE_NAME}'"
    #
    # Verify copressed file
    TMP_COMPR_FILE=${TMP_FILE_NAME}.gz
    if [ -e ${TMP_COMPR_FILE} ];then
        do_echo "${FUNCNAME}() Compressed file: '${TMP_COMPR_FILE}' was verified successfully"
        sdbu_BACKUP_FILE_NAME=${TMP_COMPR_FILE}
    else
        do_echo "${FUNCNAME}() Error! Compressed file: '${TMP_COMPR_FILE}' failed verification"   
        do_exit -1
    fi
}

# function do_dump_transfer ()
# Transfer database backup dump file to a desigated target host using the specified protocol
# @1    String  File name, The file to be trasferred over a remote host
function do_dump_transfer () {
    if [ $# -le 0 ]; then
        do_echo "${FUNCNAME}() Error! No file specified to transfer to a remote host. Terminating..."
        return 1   #exit -1                                 # Return error on no backup file
    fi
    TMP_FILE_NAME=$1                             # Grab the name of the file to transfer
    do_echo "${FUNCNAME}() Performming file tranfer:
        File Name:      '${TMP_FILE_NAME}',
        Dest Host:      '${SDBU_TRANF_HOST}',
        Dest Folder     '${SDBU_TRANF_FOLDER}'."
    if [ ${SDBU_TRANSFER} = 'Y' ] || [ ${SDBU_TRANSFER} = 'y' ]; then 
        case ${SDBU_TRANF_PROT} in
            'FTP'|'fpt')
                do_echo "${FUNCNAME}() Launching file transfer via command: 'FTP'..." 
                #SDBU_TRANF_TRC_FILE="./${APP_NAME}_TRANSFER.log"
                # Authentication is made via ~/.netrc on local host
                #sbdu_TRANF_LOG_TXT=$(ftp -n ${SDBU_TRANF_HOST} <<EOF > "./${APP_NAME}.FTP.log" 2>&1
                #sbdu_TRANF_LOG_TXT=$(ftp -n ${SDBU_TRANF_HOST} <<EOF
                sbdu_TRANF_LOG_TXT=$(ftp -n ${SDBU_TRANF_HOST} <<EOF > ${SDBU_TRANF_TRC_FILE}
quote USER ${SDBU_TRANF_USER}
quote PASS ${SDBU_TRANF_PASS}
bin
cd ${SDBU_TRANF_FOLDER}
lcd ${SDBU_BACKUP_FOLDER_DST}
pwd
debug
put $(basename ${TMP_FILE_NAME})
ls $(basename ${TMP_FILE_NAME})
EOF
)
                RC=$?
                #do_echo -en "[DEBUG] FTP Log follows:\n\t----\n\t${sbdu_TRANF_LOG_TXT}\n\t----"
                #do_echo "[DEBUG] FTP Log follows:\n\t----$(cat ${SDBU_TRANF_TRC_FILE})\n\t----"
                if [ ${RC} -ne 0 ];then
                    do_echo "${FUNCNAME}(). Error while executing FTP command." 
                    return 1   #exit -1
                fi
                do_check_fpt_log ${SDBU_TRANF_TRC_FILE} ${TMP_FILE_NAME}
                RC=$?
                ;;
            'SSH'|'ssh')
                do_echo "${FUNCNAME}() Launching file transfer via command: 'SSH/SCP'..."
                SDBU_CMD="scp ${TMP_FILE_NAME} ${SDBU_TRANF_USER}@${SDBU_TRANF_HOST}:${SDBU_TRANF_FOLDER}"
                do_echo "CMD: [${SDBU_CMD}]"
                # Authentication is made via ssh public keys on remote host
                eval ${SDBU_CMD}
                RC=$?
                ;;
        esac
        if [ ${RC} -eq 0 ]; then
            do_echo "${FUNCNAME}() File transfer program [${SDBU_TRANF_PROT}] terminated successfully [${RC}]"
        else
            do_echo "${FUNCNAME}() Error! File transfer program [${SDBU_TRANF_PROT}]terminated with error [${RC}]"
        fi
        return ${RC}    # Return the error
    fi
}

# function do_check_fpt_log ()
# Check a log file created by the ftp command to verify whether transfer was completed or not.
# @1  string    The name of the file containing the FTP log tracing
# @2  string    The file sent via FTP
function do_check_fpt_log () {
    if [ $# -lt 2 ]; then
        do_echo "${FUNCNAME}() Error! Invalud number of parameters."
        return 1   #exit -1                                 # Return error on no backup file
    fi
    TFN=$1                  # The FTP trace file
    LFN=$2                  # The local file transferred via FTP
    RFN=$(basename ${LFN})  # The remote file on the FTP server

    # Prepare integer vars for file sizes
    typeset -i LFSIZ=0
    typeset -i RFSIZ=0

    # get the file size of the local file
    [ -e ${LFN} ] && LFSIZ=$(wc -c ${LFN}| cut -d ' ' -f 1)

    # get size of file on the FTP server 
    TMPSZ=$(cat ${TFN} | grep  ${RFN} | tail -1)
    RFSIZ=$(echo ${TMPSZ} | cut -d ' ' -f 5)

    do_echo "${FUNCNAME}().Checking size of transferred file:
        Local File:     [${LFN}] - Size (Bytes): ${LFSIZ}. 
        Remote File:    [${RFN}] - Size (Bytes): ${RFSIZ}.
        FTP Trace file: [${TFN}]"
    

    if [ ${LFSIZ} -eq ${RFSIZ} ]; then
        do_echo "${FUNCNAME}().Local file matches FTP size (Local: ${LFSIZ} / Remote: ${RFSIZ})"
        RC=0
    else
        do_echo "${FUNCNAME}().ERROR!  Local file DOES NOT matche FTP size (Local: ${LFSIZ} / Remote: ${RFSIZ})"
        RC=1    #-1
    fi
    
    return ${RC}    #exit ${RC}
}

function show_version () {
    do_echo "${APP_NAME} - Version:  ${SDBU_APP_VERSION}"
}
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   M A I N
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# .-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-
# INITIALIZATION
# .-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-
# 
# Determine correct path names, app directory etc.
#APP_NAME=$(basename $0)
APP_FILE=$(basename $0)
APP_NAME=${APP_FILE/.sh/}
APP_FOLD=$(dirname $0)
cd ${APP_FOLD}  # [ ${APP_FOLD} <> "." ] && cd ${APP_FOLD}
# [DEBUG] echo "$0 | $APP_NAME | $APP_FOLD | $(pwd)"

#
# Initialize command line options to their default values
sdbu_INTERACTIVE=${sdbu_INTERACTIVE:-0}     # Assume non/interative by default
#sdbu_CONFIG_FILE=${sdbu_CONFIG_FILE:-'smartbackupdb.conf'}

#
# Read command line arguments
while [ $# -gt 0 ];do
    case $1 in
        '-h'|'--help')
            do_usage
            kill $$     #do_exit 0
            ;;
        '-c')
            shift 1
            sdbu_CONFIG_FILE="_"$1
            ;;
        '-i')
            sdbu_INTERACTIVE=1
            ;;
        '-q')
            sdbu_INTERACTIVE=0
            ;;
        '-V')
            show_version
            exit 0
            ;;
        *)
            echo -en "\nError!. Invalid argument\n\n"
            do_usage
            kill $$
    esac
    shift 1
done

#
# Read config file and set default values for unconfigured parameters
#if [ -e ./${APP_NAME}.conf ] && source ./${APP_NAME}.conf
SBDU_CONFIG_FILE="$(pwd)/${APP_NAME}${sdbu_CONFIG_FILE}.conf"
if [ -r ${SBDU_CONFIG_FILE} ];then
    #do_echo "Loading configuration file '${SBDU_CONFIG_FILE}'"
    source ${SBDU_CONFIG_FILE}
else
    do_echo "ERROR! Configuration file '${SBDU_CONFIG_FILE}' Not found."
    kill $$
fi

#
# Initialize configuration parameter to their default values
SDBU_BACKUP_FOLDER_DST=${SDBU_BACKUP_FOLDER_DST:="BackupFiles"}
SDBU_SEND_EMAIL=${SDBU_SEND_EMAIL:-"ALL"}
SDBU_COMPRESS=${SDBU_COMPRESS:-"Y"}
SDBU_DB_TYPE=${SDBU_DB_TYPE:-"postgresql"}
SDBU_BD_USER=${SDBU_BD_USER:-"dbuser"}
SDBU_DB_PASS=${SDBU_DB_PASS:-"dbpass"}
SDBU_DB_HOST=${SDBU_DB_HOST:-"localhost"}
SDBU_DB_PORT=${SDBU_DB_PORT:-"5432"}
SDBU_DB_NAME=${SDBU_DB_NAME:-"dbname"}
SDBU_BACKUP_FILE_NAME=${SDBU_BACKUP_FILE_NAME:-"SDBU_$(hostname)_${SDBU_DB_NAME}_$(date +%u).sql"}
SDBU_TRANSFER=${SDBU_TRANSFER:-"Y"}
SDBU_TRANF_PROT=${SDBU_TRANF_PROT:-"FTP"}
SDBU_TRANF_USER=${SDBU_TRANF_USER:-"ftp-user"}
SDBU_TRANF_PASS=${SDBU_TRANF_PASS:-"Change-me"}
SDBU_TRANF_HOST=${SDBU_TRANF_HOST:-"mail.infra.lan"}
SDBU_TRANF_FOLDER=${SDBU_TRANF_FOLDER:-"."}
SDBU_TRANF_EXTRA=${SDBU_TRANF_EXTRA:-""}
SDBU_ROTATE_BACKUPS=${SDBU_ROTATE_BACKUPS:=8}
SDBU_ROTATE_LOGS=${SDBU_ROTATE_LOGS:=9}
SDBU_EMAIL_NAME=${SDBU_EMAIL_NAME:-"Xatlas Backup"}
SDBU_EMAIL_TO=${SDBU_EMAIL_TO:-"user@example.com"}
#SDBU_EMAIL_SUBJECT="Smart Babckup Utility"
SDBU_EMAIL_SUBJECT=${SDBU_EMAIL_SUBJECT:-"Smart Babckup Utility"}

# Other program defaults, beyond the config file
#SDBU_PIDFILE="./${APP_NAME}.pid"                            	# The pid file
SDBU_PIDFILE="/tmp/${APP_NAME}.pid"                            	# The pid file
#SDBU_TRANF_TRC_FILE="./${APP_NAME}.trc"                     	# The trace file containing file transfer trace
SDBU_TRANF_TRC_FILE="${SDBU_BACKUP_FOLDER_DST}/${APP_NAME}.trc" # The trace file contining file transfer trace
SDBU_LOGFILE=${SDBU_BACKUP_FOLDER_DST}/${APP_NAME}.log      	# The rogram log file

# remember this instance is running!
do_create_pid_file ${SDBU_PIDFILE}

# Trap for program termination
trap "rm -f ${SDBU_PIDFILE}" SIGINT SIGQUIT SIGKILL SIGTERM EXIT

#
# Prepare backup file destination foder
if [ -d ${SDBU_BACKUP_FOLDER_DST} ]; then
    do_echo "Backup dest folder exists [${SDBU_BACKUP_FOLDER_DST}]"
else
    do_echo "Creating backup destination folder [${SDBU_BACKUP_FOLDER_DST}]"
    mkdir -p ${SDBU_BACKUP_FOLDER_DST}
fi

#
# Rotate the log file [sceduled for nuwer versions]
#rotate_file ${SDBU_LOGFILE} ${SDBU_ROTATE_LOGS}
#do_echo "log file rotation completed. Kept ${SDBU_ROTATE_LOGS} older copies."

#
# Start the log file and trace file
cp -f /dev/null ${SDBU_LOGFILE} #touch ${SDBU_LOGFILE}
cp -f /dev/null ${SDBU_TRANF_TRC_FILE}

# Adapt output on interactive mode
if [ ${sdbu_INTERACTIVE} -ge 1 ];then
    exec > >(tee ${SDBU_LOGFILE})
else
    exec > ${SDBU_LOGFILE} 2>&1
fi

do_echo "$(date) - Smart Database Backup Utility\n\n" #> ${SDBU_LOGFILE}
do_echo "Launched from tty: [$(tty)]"
do_echo "Current configuration file: [${SBDU_CONFIG_FILE}]"
do_echo "Current Log file: [${SDBU_LOGFILE}]"
do_echo "Current Pid file: [${SDBU_PIDFILE}]"
#[DEBUG] read -p "[${LINENO}].Enter to continue" VTRASH; exit -1; kill $$

# .-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-
# MAIN THREAD
# .-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-
#
# Start database backup
#sdbu_BACKUP_FILE_NAME=${SDBU_BACKUP_FOLDER_DST}/${SDBU_BACKUP_FILE_NAME}
#do_echo "DEBUG: SDBU_BACKUP_FOLDER_DST: [${SDBU_BACKUP_FOLDER_DST}}"
sdbu_BACKUP_FILE_NAME=${SDBU_BACKUP_FOLDER_DST}/${SDBU_BACKUP_FILE_NAME}
do_echo "Invoking database backup"
do_db_backup ${sdbu_BACKUP_FILE_NAME}
RC=$?
if [ ${RC} -ne 0 ];then        # && do_exit
    do_echo "Error! Latest backup program terminated with error [${RC}]"
    #SDBU_G_ERROR=$((${SDBU_C_ERROR_BACKUP} | ${SDBU_C_ERROR_BACKUP}))
    SDBU_G_ERROR=$((${SDBU_G_ERROR} | ${SDBU_C_ERROR_BACKUP}))
    #exit -1 #do_exit
fi
do_echo "${FUNCNAME}() [Log] Global error so far: ${SDBU_G_ERROR}"
#
# Compress Backup file if required
if [ ${SDBU_COMPRESS} == 'Y' ] || [ ${SDBU_COMPRESS} == 'Y' ] && [ ${SDBU_G_ERROR} -eq 0 ];then
    do_echo "File compresion flag is set to: [${SDBU_TRANSFER}]"
    do_file_compress ${sdbu_BACKUP_FILE_NAME}
    RC=$?
    if [ ${RC} -ne 0 ];then
        do_echo "${FUNCNAME}() Error! Latest file compresion terminated with error [${RC}]"
        #SDBU_G_ERROR=$((${SDBU_C_ERROR_BACKUP} | ${SDBU_C_ERROR_COMPRS}))
        SDBU_G_ERROR=$((${SDBU_G_ERROR} | ${SDBU_C_ERROR_COMPRS}))
    fi
    sdbu_TRANF_FILE=${sdbu_BACKUP_FILE_NAME}
fi
do_echo "${FUNCNAME}() [Log] Global error so far: ${SDBU_G_ERROR}"

#
# Transfer backup file if required
if [ ${SDBU_TRANSFER} = 'Y' ] || [ ${SDBU_TRANSFER} = 'y' ] && [ ${SDBU_G_ERROR} -eq 0 ]; then
    do_echo "File Transfer flag is set to: [${SDBU_TRANSFER}]"
    do_dump_transfer ${sdbu_TRANF_FILE}
    RC=$?
    if [ ${RC} -ne 0 ];then
        do_echo "${FUNCNAME}() Error! Latest file transfer program terminated with error [${RC}]"
        #SDBU_G_ERROR=$((${SDBU_C_ERROR_BACKUP} | ${SDBU_C_ERROR_TRASFR}))
        SDBU_G_ERROR=$((${SDBU_G_ERROR} | ${SDBU_C_ERROR_TRASFR}))
    fi
fi
do_echo "${FUNCNAME}() [Log] Global error so far: ${SDBU_G_ERROR}"

#
# Send the email
#if [ ${SDBU_G_ERROR} -eq 0 ]; then
if [ ${SDBU_G_ERROR} -ne 0 ]; then
    do_echo "Send-Email flag is set to: [${SDBU_SEND_EMAIL}]."
    case ${SDBU_SEND_EMAIL} in
        'ALL'|'all')
            do_echo "Sending email for condition: '${SDBU_SEND_EMAIL}'."
            sdbu_send_email "${SDBU_EMAIL_TO}" "${SDBU_LOGFILE}" "${SDBU_EMAIL_SUBJECT} Info." 
            ;;
        'ERROR'|'error')
            if [ ${SDBU_G_ERROR} -gt 0 ];then
                do_echo "Sending email for condition: '${SDBU_SEND_EMAIL}' and Error level is: '${SDBU_G_ERROR}'."
                sdbu_send_email "${SDBU_EMAIL_TO}" "${SDBU_LOGFILE}" "${SDBU_EMAIL_SUBJECT} Error!" 
            fi
            ;;
        'SUCCESS'|'success')
            if [ ${SDBU_G_ERROR} -eq 0 ];then
                do_echo "Sending email for condition: '${SDBU_SEND_EMAIL}' and Error level is: '${SDBU_G_ERROR}'."
                sdbu_send_email "${SDBU_EMAIL_TO}" "${SDBU_LOGFILE}" "${SDBU_EMAIL_SUBJECT} Success!" 
            fi
            ;;
        'NEVER'|'never')
            do_echo "Skipping email."
    esac
else
	do_echo "ERROR! Not sending email due NO ERROR."
fi

do_echo "Program completed"
exit ${SDBU_G_ERROR}    #do_exit

# end-of-file
