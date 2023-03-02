#!/bin/bash

# Username to access the MySQL server e.g. dbuser
USERNAME=root
# Username to access the MySQL server e.g. password
PASSWORD=pass
# Host name (or IP address) of MySQL server e.g localhost
DBHOST=localhost
# List of DBNAMES for Daily/Weekly Backup e.g. "DB1 DB2 DB3"
DBNAMES="all"
# Backup directory location e.g /backups
BACKUPDIR="/backups"
# Days to keep in the daily directory
KEEP_DAYS=7
# Weeks to keep in the weekly directory
KEEP_WEEKS=4
# Months to keep in the monthly directory
KEEP_MONTHS=12
# Log days to keep
KEEP_LOGS=60
# Backup filesystem
FILESYSTEM=

# List of DBBNAMES for Monthly Backups.
MDBNAMES="mysql $DBNAMES"
# List of DBNAMES to EXLUCDE if DBNAMES are set to all (must be in " quotes)
DBEXCLUDE="information_schema"
# Include CREATE DATABASE in backup?
CREATE_DATABASE=yes
# Which day do you want weekly backups? (1 to 7 where 1 is Monday)
DOWEEKLY=1
# Choose Compression type. (gzip or bzip2)
COMP=gzip
# Compress communications between backup server and MySQL server?
COMMCOMP=no
# The maximum size of the buffer for client/server communication. e.g. 16MB (maximum is 1GB)
MAX_ALLOWED_PACKET=
# For connections to localhost. Sometimes the Unix socket file must be specified.
SOCKET=

PATH=/usr/local/bin:/usr/bin:/bin:/usr/local/mysql/bin
# Datestamp e.g 2002-09-21
DATE=`date +%Y-%m-%d_%Hh%Mm`
# Day number of the week 1 to 7 where 1 represents Monday
DNOW=`date +%u`
# Date of the Month e.g. 27
DOM=`date +%d`
# Month e.g January
M=`date +%B`
# Logfile Name
LOGFILE=$BACKUPDIR/logs/$DBHOST-$DATE.log
# Error Logfile Name
LOGERR=$BACKUPDIR/logs/ERRORS_$DBHOST-$DATE.log
# OPT string for use with mysqldump ( see man mysqldump )
OPT="--quote-names --opt"

# Add --compress mysqldump option to $OPT
if [ "$COMMCOMP" = "yes" ]; then
	OPT="$OPT --compress"
fi

# Add --compress mysqldump option to $OPT
if [ "$MAX_ALLOWED_PACKET" ]; then
	OPT="$OPT --max_allowed_packet=$MAX_ALLOWED_PACKET"
fi

# Check Backup Directory exists.
if [ ! -e "$BACKUPDIR" ]; then
	mkdir -p "$BACKUPDIR"
fi

# Check Logs Directory exists.
if [ ! -e "$BACKUPDIR/logs" ]; then
	mkdir -p "$BACKUPDIR/logs"
fi

# IO redirection for logging.
touch $LOGFILE
exec 6>&1       # Link file descriptor #6 with stdout.
                # Saves stdout.
exec > $LOGFILE # stdout replaced with file $LOGFILE.
touch $LOGERR
exec 7>&2       # Link file descriptor #7 with stderr.
                # Saves stderr.
exec 2> $LOGERR # stderr replaced with file $LOGERR.

if [ "$KEEP_LOGS" ]; then
	find "$BACKUPDIR/logs" ! -newermt "$KEEP_LOGS days ago"  -type f -delete
	echo "Cleaned $BACKUPDIR/logs"
fi

rm -rfv "$BACKUPDIR/latest/"
mkdir -p "$BACKUPDIR/latest"

# Check Daily Directory exists.
if [ ! -e "$BACKUPDIR/daily" ]; then
	mkdir -p "$BACKUPDIR/daily"
	echo "Created $BACKUPDIR/daily"
fi
if [ "$KEEP_DAYS" ]; then
	find "$BACKUPDIR/daily" ! -newermt "$KEEP_DAYS days ago"  -type f -delete
	echo "Cleaned $BACKUPDIR/daily"
fi

# Check Weekly Directory exists.
if [ ! -e "$BACKUPDIR/weekly" ]; then
	mkdir -p "$BACKUPDIR/weekly"
	echo "Created $BACKUPDIR/weekly"
fi
if [ "$KEEP_WEEKS" ]; then
	find "$BACKUPDIR/weekly" ! -newermt "$KEEP_WEEKS weeks ago"  -type f -delete
	echo "Cleaned $BACKUPDIR/weekly"
fi

# Check Monthly Directory exists.
if [ ! -e "$BACKUPDIR/monthly" ]; then
	mkdir -p "$BACKUPDIR/monthly"
	echo "Created $BACKUPDIR/monthly"
fi
if [ "$KEEP_MONTHS" ]; then
	find "$BACKUPDIR/monthly" ! -newermt "$KEEP_MONTHS months ago"  -type f -delete
	echo "Cleaned $BACKUPDIR/monthly"
fi

echo "Auto Mysql Backup"
echo "Backup Start Time `date`"
echo ================================================================

# Check if CREATE DATABSE should be included in Dump
if [ "$CREATE_DATABASE" = "no" ]; then
	OPT="$OPT --no-create-db"
else
	OPT="$OPT --databases"
fi

# Hostname for LOG information
if [ "$DBHOST" = "localhost" ] && [ "$SOCKET" ]; then
	OPT="$OPT --socket=$SOCKET"
fi

# If backing up all DBs on the server
if [ "$DBNAMES" = "all" ]; then
  DBNAMES="`mysql --user=$USERNAME --password=$PASSWORD --host=$DBHOST --batch --skip-column-names -e "show databases"| sed 's/ /%/g'`"

	# If DBs are excluded
	for exclude in $DBEXCLUDE; do
		DBNAMES=`echo $DBNAMES | sed "s/\b$exclude\b//g"`
	done

  MDBNAMES=$DBNAMES
fi

for DB in $DBNAMES; do
	MDB="`echo $MDB | sed 's/%/ /g'`"

	FILE="${MDB}_$DATE.$M.$MDB.sql"

	mysqldump --user=$USERNAME --password=$PASSWORD --host=$DBHOST $OPT "$MDB" > "$BACKUPDIR/latest/$FILE"

	SUFFIX=""
	if [ "$COMP" = "gzip" ]; then
		echo "Information for $BACKUPDIR/latest/$FILE"
		gzip -fv "$BACKUPDIR/latest/$FILE"
		SUFFIX=".gz"
	elif [ "$COMP" = "bzip2" ]; then
		echo "Information for $BACKUPDIR/latest/$FILE"
		bzip2 -f -v $BACKUPDIR/latest/$FILE 2>&1
		SUFFIX=".bz2"
	else
		echo "No compression option set"
	fi

	echo ================================================================

	echo "Backed up $MDB - $FILE"

	if [ $DOM = "01" ]; then
		if [ ! -e "$BACKUPDIR/monthly/$MDB" ]; then
			mkdir -p "$BACKUPDIR/monthly/$MDB"
		fi
		cp "$BACKUPDIR/latest/$FILE$SUFFIX" "$BACKUPDIR/monthly/$MDB";
		echo "Monthly backup $MDB - $FILE"
	fi

	if [ $DNOW = $DOWEEKLY ]; then
		if [ ! -e "$BACKUPDIR/weekly/$MDB" ]; then
			mkdir -p "$BACKUPDIR/weekly/$MDB"
		fi
		cp "$BACKUPDIR/latest/$FILE$SUFFIX" "$BACKUPDIR/weekly/$MDB";
		echo "Weekly backup $MDB - $FILE"
	fi

	if [ ! -e "$BACKUPDIR/daily/$MDB" ]; then
		mkdir -p "$BACKUPDIR/daily/$MDB"
	fi
	cp "$BACKUPDIR/latest/$FILE$SUFFIX" "$BACKUPDIR/daily/$MDB"

	echo ================================================================
done

echo "Total disk space used for backup storage..."
echo `du -hs "$BACKUPDIR"`
echo
echo "Total disk space available..."
if [ "$FILESYSTEM" ]; then
	echo `df -h | grep "$FILESYSTEM"`
else
	echo `df -h`
fi
echo

echo "Backup End Time `date`"

#Clean up IO redirection
exec 1>&6 6>&- # Restore stdout and close FILE descriptor #6.
exec 1>&7 7>&- # Restore stdout and close file descriptor #7.

if [ -s "$LOGERR" ]; then
	STATUS=1
else
	STATUS=0
fi

exit $STATUS
