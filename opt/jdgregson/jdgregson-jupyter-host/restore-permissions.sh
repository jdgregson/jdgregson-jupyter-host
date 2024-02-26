#!/bin/bash

# Sourece: https://stackoverflow.com/a/38163771

SELF_DIR=`git rev-parse --show-toplevel`
DATABASE=/opt/jdgregson/jdgregson-jupyter-host/permissions

echo -n "Restoring permissions..."

IFS_OLD=$IFS; IFS=$'\n'
while read -r LINE || [[ -n "$LINE" ]];
do
   ITEM=`echo $LINE | cut -d ";" -f 1`
   PERMISSIONS=`echo $LINE | cut -d ";" -f 2`
   USER=`echo $LINE | cut -d ";" -f 3`
   GROUP=`echo $LINE | cut -d ";" -f 4`

   # Set the file/directory permissions
   chmod $PERMISSIONS "$1/$ITEM"

   # Set the file/directory owner and groups
   chown $USER:$GROUP "$1/$ITEM"

done < $DATABASE
IFS=$IFS_OLD

echo "OK"

exit 0

