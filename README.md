
 `-*- coding:utf-8, indent=tab, tabstop=4 -*-`


SmartBackup is free software tool distributed under : the GNU General Public License version 3. for more detail concerning the license, please read the file **README.txt**.

The goal of this tool is to help system administrators to automate single or multiple backups of MySQL and Postgresql databases.

## Introduction

This Smart Backup utility (SBU) was developed to help GNU Linux sysadmin to take database backups with no headache.  The tool can take any database backup from any host, either locally or remotely, storing the backup file in a preconfigured server via ssh or ftp protocol.

There are many situations in which sysadmins have the need of run unattended backups of one or more databases of their production systems keeping some useful information of what's happening during the backup session in terms of possible log errors. Furthermore, sysadmins have the needs of performing different database backups with a well documented procedure which must be homogeneous across all systems, the sake of the safe data restore.

For the above reasons, this tool is a good candidate to be a sysadmin companion.

## Why another backup utility

Despite there's a plenty of great backup software out there, they can be complex, with a huge footprint, difficult to adopt for old Linux distributions, needs agent or something similar.

The idea was to implement a simple backup utility that could be executed on *any* GNU Linux system,  using its native shell: **the Bash**; beyond few dependencies on some commands which are part of a standard installation. All of that, aiming to introduce the minimal impact on the target system.

Another important reason at the base of the development of Smart Backup Utility regard the Compatibility. Having said that the ***bourne again shell*** is the real engine of the tool, we wanted to make sure that the tool could run even on outdated version on such shell, for compatibility with older systems.

## Features
Once adjusted the configuration file to the specific needs, Smart Backup Utility can do the following for you.

* **Keep latest backups** . Through the configuration file, it is possible to keep a a preconfigured number of recent backups by rotating all the previous backup files in the local backup storage folder. This offers the possibility of going back to the desired backup, in the case of a database restore in needed.
* **Backup file compression**. Since there are situation in which a large files are difficult to handle (transfer over the network, store in a USB stick, etc.) backup file can be automatically compressed via a specific configuration parameter in the configuration file.
* **File transfer over remote storage**. Transfer via FTP or SSH of the latest completed backup file to a remote storage.
* **Email notification**. Email notification in case of error, success or regardless (email sent anyway) 
* **Log file**. Log file for last latest backup sessions, for error analysis and debug purposes



## Installation

### Prerequisites

The following prerequisites are needed when running SmartBackup.

 * **bash** version 3.0 or greater
 * **ftp** (client) version 0.17 or greater
 * ~~basename (Typically installed by default on most Linux distributions)~~
 * ~~dirname (Typically installed by default on most Linux distributions)~~
 * **mysqldump** for MariaDB and MySQL (Typically part of database server installation)
 * **pg_dump** for PostgreSQL (Typically part of database server installation)
 * **gzip** for file compression
 * **zip, unzip** for file compression
 * **Sendmail** or **Postfix** for mail sending
 
**Note:**
From version 0.1.0 commands **basename** and **dirname** are replaced with a Bash workaround, so are no longer needed as prerequisites.


## Package install

 1. Download the archive fle from Gitub
 2. Extract in a destination directory (suggested: /usr/local/smartbackup)
 3. Copy the file smartbackup-sample.conf to smartbackup.conf (the default configuration file)
 4. Modify the default configuration file and/or create a new one
 
### File permissions

In order to be executed as any use (other rhan 'root'), there are some issues you must be aware of.

 * For security reasons the tool should be ran by a user other than 'root'
 * The destination backup folder (`SDBU_BACKUP_FOLDER_DST`) must created prior the first run and must be writible by the user

### Execution

 1. Move to the folder where the package is located
 2. Execute `smartbackup.sh` and examine the log to verify whether output is as expected.

The tool invocation can be put under the control of system **cron** by adding the a line similar to the one that  follows as example.

```
0 3 * * * /bin/bash /usr/local/smartbackup/smartbackup.sh -c TEST > /dev/null 2>&1
```

Please note that the `cron` command line is preceded by `/bin/bash`. This is necessary since `cron` tries to execute the command using `sh` and not all systems uses the same mechanism. This workaround forces Smartbackup to be executed with **bash** without the need to set environment variable `SHELL` in the crontab file, which may be in contrast with other crontab lines.

For more information please see CRONTAB(5) man pages.

## Authentication
You must consider that, in case the database backup file has to be transferred over a remote host for storage, an authentication may be needed on the remote host, to store the file.

SmartBackup can autonomously handle the authentication in the following way.

### Ftp authentication
FTP authentication is based on file `.netrc` which should reside in the home directory of the user which is running the script. For more information on netrc file content, please see **netrc** man pages.

### Ssh authentication
Scp/ssh authentication is based upon ssh public key which should be generated locally and installed on the remote host .

[TOBE COMPLETED]

## Simple Man Page

SYNOPSIS

```
smartbackup.sh [-h | --help][-c config_name] [-q | -i] [-V]
```
### ARGUMENTS

**-h** or **--help**	Show a brief help message and exit

**-c NAME**		Configuration name. The tool is executed with configuration file named 'NAME', so that a configuration file with name **smartbackup_NAME.conf** must exist in the application root directory. No defaut value for ```NAME``` so that the standard configuratio file **smartbackup.conf** is loaded by default.

**-i**					Interactive (default). The tool will show all runtime log information.  This does not affect log file, which is created and populated anyway.

**-q**					Quiet. Log information are not shown on the screen (Does not affect log file, which is created and populated anyway)

**-V**					Show application version and exit immediately.


### Multiple configuration file

Since the tool is intended to run in a system where there can be a number of databases of different nature (please see 'Features' above), sysadmin can create different configuration files in the app root directory, for any of the database to put under the control of SmartBackup. All those files cane be named **smartbackup_NAME.conf**, where `NAME` is a string identifying different specific configuration name to read for different instances of the tool.

If no configuration name is specified in the command line the default one (i.e. **smartbackup.conf**) is read and applied.

## Configuration Parameters

The following section describes all the configuration parameters that can be customized in the application configuration file

### SDBU_BACKUP_FOLDER_DST
This is the destination backup folder (i.e. where the backup file is finally stored).
Indicate the relative path of the folder

#### Default value: BackupFiles

#### Example:
SDBU_BACKUP_FOLDER_DST=BackupFiles

### SDBU_BACKUP_FILE_NAME
A string to be used as a template for the database backup file.
It is recommended that the filename terminates with the suffix '.sql'.

#### Default value: "SDBU-$(hostname)-${SDBU_DB_NAME}_$(date +%u).sql"

#### Example:

```
SDBU_BACKUP_FILE_NAME=XatlasDatabase_$(hostname)_$(date +%u).sql
```

### SDBU_SEND_EMAIL
An integer specifying when email has to be sent carrying the completion backup status.
Allowed vaues are:

 * **ALL**		Send an email for each condition
 * **ERROR**		Send an email on error condition only
 * **SUCCESS**	Send an email on successful condition only
 * **NONE**  	Never send out email

#### Default value: ALL

#### Example:

```
SDBU_SEND_EMAIL=ALL
```

### SDBU_COMPRESS
 This is a flag indicathing if the final backup has to be compressed before transfer

#### Allowed values are:

 * **'Y'** | **'y'** 	Compress the backup file
 * **'N'** | **'n'** 	Do NOT compress the backup file

### Default value: Y

#### Example:

```
SDBU_COMPRESS=Y
```

### SDBU_DB_TYPE
This is a string indicating the database type

#### Allowed values are:

 * '**postgresql**'  For Postgresql database
 * '**mysql**'       For Mysql database
 * '**mariadb**'     For Maria database

#### Default value:    "postgresql"

#### Example:

```
SDBU_DB_TYPE="postgresql"
```

### SDBU_BD_USER
This is a string indicating the Database username

#### Default value: dbuser

#### Example:

```
SDBU_BD_USER="axsuser"

```

### SDBU_DB_PASS
This is a string indicating the Database password

#### Default value: "dbpass"

#### Example:

```
SDBU_DB_PASS=""
```

### SDBU_DB_HOST
This is a string indicating the Database host. Indicate the host name either as IP Address or FQDN

#### Default value: localhost

#### Example:

```
SDBU_DB_HOST="bckserver.domain.com"
```

### SDBU_DB_PORT
This is a string indicating the Database TCP/IP port where it is listening

#### Default value: 5432

#### Example:

```
SDBU_DB_PORT="5432"
```

### SDBU_DB_NAME
This is a string indicating the Database name

#### Default value: "dbname"

#### Example:

```
SDBU_DB_NAME="AXS_DB"
```

### SDBU_TRANSFER
This is a flag inficating if the file has to be transferred upon successful completion

#### Allowed values are:

 * **'Y'** | **'y'** 	Compress the backup file
 * **'N'** | **'n'** 	Do NOT compress the backup file

#### Default value: "Y"

#### Example:

```
SDBU_TRANSFER=Y
```

### SDBU_TRANF_PROT
This is a string indicating the transfer protocol

#### Allowed values are:

 * **FTP**			Use FTP Protocol
 * **SCP**			Use SCP Protocol

#### Default value: "FTP"

#### Example:

```
SDBU_TRANF_PROT="FTP"
```

### SDBU_TRANF_USER
This is a string indicating the username to be used for SDBU_TRANF_PROT connection

#### Default value: "ftp-user"

#### Example:

```
SDBU_TRANF_USER="my-user"
```

### SDBU_TRANF_PASS
This is a string indicating the password to be used for SDBU_TRANF_PROT connection

#### Default value: "Change-me"

#### Example:

```
SDBU_TRANF_PASS="my-password"
```

### SDBU_TRANF_HOST
This is a string indicating the destination host to be used for SDBU_TRANF_PROT connection. Indicate the host name either as IP Address or FQDN

#### Default value: "mail.infra.lan"

#### Example:

```
SDBU_TRANF_HOST="mail.infra.lan"
```

### SDBU_TRANF_FOLDER
This is a string indicating the absolute path of the destination folder on the remote host

#### Default value: "."

#### Example:

```
SDBU_TRANF_FOLDER="/home/operator/ftptest"
```

### SDBU_TRANF_EXTRA
This is a string indicating extra arguments to be used for SDBU_TRANF_PROT connection. Indicate the host name either as IP Address or FQDN.

#### Default value: "" (empty)

#### Example:

```
SDBU_TRANF_EXTRA=""

```

### SDBU_ROTATE_BACKUPS
This is an integer indicating how many copies of Baclup files must be kept when rotating. If the value is set to 0 (zero) no rotatiion is applied.

#### Default value: 7

#### Example:

```
SDBU_ROTATE_BACKUPS=6
```

### SDBU_ROTATE_LOGS
This is an integer indicating how many copies of Log files must be kept when rotating. If the value is set to 0 (zero) no rotatiion is applied.

#### Default value: 7

#### Example:

```
SDBU_ROTATE_LOGS=12
```

### SDBU_EMAIL_NAME
This is a string to be used as "From" name, when sending emails

#### Default: "Xatlas Backup"

#### Example:

```
SDBU_EMAIL_NAME="Smart Database Backup Utility"
```

### SDBU_EMAIL_TO
This is a string indicating the email receipient, when sending emails

#### Default: "user@example.com"

#### Example:

```
SDBU_EMAIL_TO="operator@mail.infra.lan"
```

### SDBU_EMAIL_SUBJECT
This is the customized email subject when sending the email

#### Default: "Smart Babckup Utility"

#### Example:

```
SDBU_EMAIL_SUBJECT="Smart Backup for CMDBuild_30"
```
