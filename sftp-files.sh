#!/bin/bash
# These are variables that we use to create accounts, set expire date, and track requestors
# This script is realeased in t

## Begin variable Definitions

# Hostname of the SFTP server
sftpHostName="sftp.example.tld"

# (Optional) Help Message.  You can have this echo to the console along with hostname, username and generated
# password to make it easy to copy and paste into an email.  An example is commented below, otherwise this 
# variable is left blank.

#HelpMessage="Please see instructions to setup SFTP sites at https://exampe.com/sftp/help. Use the below information for the address, username and password."

HelpMessage=""

# Lockfile used to check health of mounted share (usefull for checking network mounted shares).
Lockfile=".mntchk.lock"

# Generate a 15 digit password only once.  This is then set as a variable.
UserPassWD=`pwgen -s 15 1`

# Location and name of log file.  The log file is structured as a syntax and can be read directly in 
# most productivity applications (such as Excel, LibreOffice, or Google Docs).
LogFile="/var/log/sftp-files.log.csv"

# Shell for the user
UserShell="/usr/bin/scponly"

# Group name or GID (GID group must exist) that is configured for chrootin in the sshd_conf file.
PrimaryGroup="sftponly"

# Location where user's home directory lives.
BaseDIR="/mnt/sftp_data"

# Date and time the user was requested.
DateCreated=`date +%Y%m%d`

# The time this user was created.
TimeCreated=`date +%H:%M`

# This takes the provided password and encrypts it in a format suitable for useradd.
# The second variable in the crypt function is the salt
encpass=`openssl passwd -1 $UserPassWD`

# 
## End Variable definitons

## Begin Library functions and variables

USAGE="This script requires you to specify the requested username as well as the person requesting it.  It also takes '-s' (to simulate) to see what variables are assigned.
-s 		-- Simulate (do nothing)
-u <username> 	-- Username to be created (required)
-r <rusername>	-- Username of the person making this request (required)
-h		-- Help (this text)

For example: sftp-files.sh -u sftp_user -r requesting_user"


## End Library functions and variables

## Begin Function Definitions

CheckMount()
{
# Check to see if the location where the files are stored is mounted properly
# and aborts the procedure if it isn't.  Particularly usefull if these files are 
# stored on an NFS, iSCSI, or SMB network share.

if [[ ! -f "$BaseDIR""/""$Lockfile" ]]; then
	echo "SFTP share is not mounted!  Mount and try again, aborting ..."
	exit 1
fi
}

checkuser()
{
 # Check to see if the user exists
egrep -i "^$NewUserName:" /etc/passwd
if [ $? -eq "0" ]; then 
	echo "User $NewUserName already exists. Please choose another username."
	exit 1
  else
	echo "User $NewUserName does not exist, proceeding."
fi
}

checkfolder()
{
if [[ -d "$BaseDIR""/""$NewUserName" ]]; then
	echo  "Folder "$BaseDIR""/""$NewUserName" already exists, exiting!"
	exit 1
  else
	echo "Folder "$BaseDIR""/""$NewUserName" does not exist, proceeding."
fi
}

createuser()
{
useradd -g $PrimaryGroup -p $encpass -b $BaseDIR -s $UserShell -m $NewUserName 
if [ $? -ne "0" ]; then
	echo "$NewUserName was not added successfully, aborting..."
	exit 1
fi
chown root "/$BaseDIR/$NewUserName"
chmod 750 "/$BaseDIR/$NewUserName"
mkdir "/$BaseDIR/$NewUserName/incoming"
mkdir "/$BaseDIR/$NewUserName/outgoing"
chown $NewUserName "/$BaseDIR/$NewUserName/incoming"
chown $NewUserName "/$BaseDIR/$NewUserName/outgoing"
chmod 770 "/$BaseDIR/$NewUserName/incoming"
chmod 770 "/$BaseDIR/$NewUserName/outgoing"
}

logexist()
 {
 # We are checking for the existance of the log file
if [[ ! -f $LogFile  ]] ; then
	echo "DateCreated,TimeCreated,RequestorUserName,NewUserName,UserPassWD" > $LogFile
fi 
}

logoutput()
{
 	printf "$DateCreated,$TimeCreated,$RequestorUserName,$NewUserName,$UserPassWD\n" >> $LogFile
	chmod 644 $LogFile
}

checkinput()
{
limit=`echo ${#NewUserName}`
echo $NewUserName |egrep -q "^[-a-zA-Z0-9]+$"
if [ "$?" -ne "0" ]; then
	echo ERROR name/username must only contain alphanumeric characters like -a-zA-Z0-9
	exit 1
else
	echo $RequestorUserName |egrep -q "^[-a-zA-Z0-9]+$"
	if [ "$?" -ne "0" ]; then
		echo ERROR name/username must only contain alphanumeric characters like -a-zA-Z0-9
		exit 1
	fi
fi
if [ "$limit" -gt 32 ]; then
	echo "$NewUserName is longer than 32 characters, Aborting..."
	exit 1
fi

}

instructionsoutput()
{
echo
echo $HelpMessage
	    echo
            echo "Hostname: $sftpHostName"
            echo "Username: $NewUserName"
	    echo "Password: $UserPassWD"
}

# End Function Definitons

CheckMount ;

# Check to see if pwgen and useradd exist on this system.  This script requires them.
declare -a CMDS=( "pwgen" "useradd" "openssl" )
for i in $CMDS
do
        # command -v will return >0 when the $i is not found
        command -v $i >/dev/null && continue || { echo "$i command not found, please install it or notify your system administrator."; exit 1 ; }
done

# Check to see if there were any parameters passed, if not, display basic usage example.
if [ "$#" = "0" ]; then
        echo "$USAGE"
        exit 1
fi

while getopts "shu:r:" opt ; do
	case "$opt" in

	  u) uflag=1
	     NewUserName=$OPTARG ;;
	  r) rflag=1
	     RequestorUserName=$OPTARG ;;
	  s) sflag=1;;
	  h) echo $USAGE;;
	  \?) echo "Invalid option: -$OPTARG"
	      echo $USAGE
	      exit 1;;
	  :) echo "$USAGE";;
esac
 
done

if [[ "$sflag" == "1" ]] ; then
	checkinput ; 
	checkuser ;
	checkfolder ;
	printf "The following is what would be executed without the -s flag:
useradd -g $PrimaryGroup -p $UserPassWD -b $BaseDIR -s $UserShell $NewUserName\n
Other Variables\nuflag=$uflag NewUserName=$NewUserName rflag=$rflag RequestorUserName=$RequestorUserName sflag=$sflag DateCreated=$DateCreated TimeCreated=$TimeCreated\n"
	exit 0
  else
      if  [[ "$uflag" == "1" ]] && [[ "$rflag" == "1" ]] ; then 
	logexist ;
	checkinput ;
	checkuser ;
	checkfolder ;
	createuser ;
	logoutput;
	instructionsoutput ;
	else
      echo $USAGE
      exit
      fi
fi
