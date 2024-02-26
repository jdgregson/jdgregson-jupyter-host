#!/bin/bash

# Setup script for jdgregson-jupyter-host
# Usage:
# Author: Omid Ariyan 
# Author: Jonathan Gregson <hello@jdgregson.com>
# Source: https://stackoverflow.com/a/38163771

SELF_DIR=`git rev-parse --show-toplevel`
DATABASE=/opt/jdgregson/jdgregson-jupyter-host/permissions

echo -n "Restoring permissions..."

cd "$1"

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

done < "$1/$DATABASE"
IFS=$IFS_OLD

echo "OK"

exit 0

