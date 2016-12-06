#!/bin/bash +x

function execute_migration {
	migration=$1
	migration_control_table=$2
        migrantion_execution_control_query="select * from $migration_control_table where filename='$migration'"
	migration_executed=$(cqlsh "$CASSANDRA_PORT_9042_TCP_ADDR" --execute "$migrantion_execution_control_query" | grep rows)

	if [ "$migration_executed" = "(0 rows)" ]; then
	   echo "Migration $migration wasn't executed. Running it right now..."

	   #execute the patch
	   cqlsh "$CASSANDRA_PORT_9042_TCP_ADDR" --file $migration

	   if [ "$?" = "0" ]; then
		echo "$migration has done."
	   else
		echo "$migration has failed. Aborting the rest."
		exit 1
	   fi

	   insert_command="insert into $migration_control_table (filename, executed_at) values ('$migration', dateof(now()));"
	   cqlsh "$CASSANDRA_PORT_9042_TCP_ADDR" --execute "$insert_command"
	else
	   echo "Migration $migration already executed"
	fi
}

checkFileSanity() {
  if [ ! -f $1 ]; then
    echo "File $1 was not found"
    exit 1
  fi
}

processFolderWithPrefixedFiles(){
   CSV_FILE=$1
   MIGRATIONS_FOLDER=$2
   keyspace=$3

   echo "Reading file $CSV_FILE"
   DATALIST=$(cat $CSV_FILE)

   echo "Trying to execute the migrations of $MIGRATIONS_FOLDER"
   echo ""
   for FILE in $DATALIST; do
	PATCHFOLDER="$MIGRATIONS_FOLDER/$FILE"
	PATCHCOMMENT="-- $FILE "
	checkFileSanity $PATCHFOLDER
	#echo "Executing migration : $PATCHFOLDER"
	execute_migration $PATCHFOLDER "$keyspace.migrations"
	#echo ""
   done
   echo ""
}

sleep 30
echo "Starting the keyspace $KEYSPACE_NAME setup process..."
cqlsh "$CASSANDRA_PORT_9042_TCP_ADDR" --file "/opt/create_keyspace.cql"
processFolderWithPrefixedFiles "/opt/migrations/migrations.csv" "/opt/migrations" $KEYSPACE_NAME
echo "Finished"

