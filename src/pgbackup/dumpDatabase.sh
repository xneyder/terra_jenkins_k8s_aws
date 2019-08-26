DUMP_FILE_NAME="backupOn`date +%Y-%m-%d-%H-%M`.dump"
echo "Creating dump: $DUMP_FILE_NAME"

pg_dump -C -w --format=c --blobs > $DUMP_FILE_NAME

if [ $? -ne 0 ]; then
  rm $DUMP_FILE_NAME
  echo "Back up not created, check db connection settings"
  exit 1
fi

echo 'Successfully Backed Up'
aws s3 cp $DUMP_FILE_NAME s3://pgbackup.xneyder.danieljj.com --grants read=uri=http://acs.amazonaws.com/groups/global/AllUsers
exit 0