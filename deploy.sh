#!/bin/sh

# @param: Source location of the artifact
# @param: Destination location for the deployment/ TOMCAT instance location
# @param: Artifact name
# @return: Status of the execution.
deploy_artifact () {
   if [  -n "$1" ] && [  -d "$1" ] && [  -n "$2" ] && [ -d "$2" ] && [ -n "$3" ];
   then
      deploy_dir=$(echo "$3" | cut -d "." -f1)
      #Check and terminate tomcat process
      if [ $(ps -ef | grep tomca[t] | wc -l) -gt 0 ] ;
      then
         log " [DEPLOY] Tomcat service is running."
         attempts=0
         while [ $(ps -ef | grep tomca[t] | wc -l) -gt 0 ]
         do
            if [ "$attempts" -lt 2 ];
            then
               log " [DEPLOY] Attempting to stop the tomcat service."
               "$2/bin/shutdown.sh"
               sleep 10
            elif [ "$attempts" -eq 2 ];
            then
               log " [DEPLOY] Attempting to kill the tomcat service."
               ps -ef | grep tomca[t] | awk '{print $2}' | xargs kill -9
            elif [ "$attempts" -gt 3 ];
            then
               log " [DEPLOY] Unable to stop tomcat process. Terminating the deployment process!."
               return 1
            fi
         attempts=`expr "$attempts" + 1`
         done
      fi

      #Remove the old web archive files
      log " [DEPLOY] Attempting to clean up $deploy_dir files from the tomcat container"
      if [ -f "$2/webapps/$3" ]
      then
         log " [DEPLOY] $deploy_dir web archive ( $2/webapps/$3 ) detected. Attempting to delete it."
         rm "$2/webapps/$3"
         log " [DEPLOY] $2/webapps/$3 has been deleted successfully."
      else
         log " [DEPLOY] There is no artifact with name $3 in $2/webapps/ directory!."
      fi

      if [ -d "$2/webapps/$deploy_dir" ]
      then
         log " [DEPLOY] $deploy_dir web directory ( $2/webapps/$deploy_dir ) detected. Attempting to delete it!."
         rm -rf "$2/webapps/$deploy_dir"
         log " [DEPLOY] $2/webapps/$deploy_dir has been deleted successfully."
      else
         log " [DEPLOY] There is no web directory for $deploy_dir present in $2/webapps/ path!."
      fi

      if [ -d "$2/work/Catalina/localhost/$deploy_dir" ]
      then
         log " [DEPLOY] $2/work/Catalina/localhost/$deploy_dir directory detected. Attempting to delete it."
         rm -rf "$2/work/Catalina/localhost/$deploy_dir"
         log " [DEPLOY] $2/work/Catalina/localhost/$deploy_dir has been deleted successfully."
      else
         log " [DEPLOY] There is no web directory for $deploy_dir present in $2/work/Catalina/localhost/$deploy_dir path!."
      fi

      #Clean up old logs
      log " [DEPLOY] Attempting to delete old logs..."
      if [ -d "$2/logs" ];
      then
         if [ $(ls -1 $2/logs | wc -l) -gt 0 ];
         then
            rm -rfv "$2/logs/*.txt"
            rm -rfv "$2/logs/*.log"
            rm -rfv  "$2/logs/*.out"
            log " [DEPLOY] Old logs has been successfully deleted."
         else
            log " [DEPLOY] No logs found. Skipping the delete process."
         fi
      fi

      #Copy web archive to tomcat
      log " [DEPLOY] Copying $deploy_dir artifact to tomcat container"
      if [ -f "$1/$3" ];
      then
         if [ -d "$2/webapps" ];
         then
            cp -p "$1/$3" "$2/webapps/"
            # sleep 10
            log " [DEPLOY] Successfully copied artifact from workspace to tomcat container."
         else
            log " [DEPLOY] Unable to find $2/webapps directory. Terminating the deployment process!."
         return 1
         fi
      else
         log " [DEPLOY] No artifacts present for $deploy_dir in the $1 directory with name $3. Terminating the deployment process!."
         return 1
      fi
   
      #Start Tomcat Server
      log " [DEPLOY] Starting Tomcat Service..."
      if [ -f "$2/bin/startup.sh" ];
      then
         attempts=0
         while [ $(ps -ef | grep tomca[t] | wc -l) -lt 1 ]
         do
            if [ "$attempts" -lt 2 ];
            then
               log " [DEPLOY] Attempting to start the tomcat service."
               "$2/bin/startup.sh"
               sleep 10
            elif [ "$attempts" -gt 3 ];
            then
               log " [DEPLOY] Unable to start tomcat process. Please contact system administrator for further information."
               return 1
            fi
            attempts=`expr "$attempts" + 1`
         done
      else
         log " [DEPLOY] Unable to find startup.sh in $2/bin directory . Please contact system administrator for further information."
         return 1
      fi
      
      log " [DEPLOY] Ensuring the status of tomcat process."
      if [ $(ps -ef | grep tomca[t] | wc -l) -gt 0 ];
      then
         log " [DEPLOY] Tomcat process is running."
         return 0
      else
         log " [DEPLOY] Unable to start tomcat process. Please contact system administrator for further information."
         return 1
      fi
   else
      log " [DEPLOY] Artifact name, Source and Target destinations are mandatory!."
      return 1
   fi
}

# @param: Artifact name that needs to be backed up
# @param: Source directory (PATH details)
# @param: Destination directory (PATH details)
# @param: Temp directory (PATH details)
# @return: Status of the execution.
copy_artifacts () {
#Backup the existing war
   if [ -n "$2" ];
   then
      if [ -d "$2" ];
      then
         log " [BACKUP] Found $2 directory."
         if [ -n "$1" ];
         then
            if [ -f "$2/$1" ];
            then
               log " [BACKUP] Detected $1 artifact in $2 directory."
               if [ -n "$3" ];
               then
                  if [ -d "$3" ];
                  then
                     log " [BACKUP] Found $3 directory."
                     if [ $(ls -1 $3 | wc -l) -gt 0 ];
                     then
                        log " [BACKUP] Found $(ls -1 $3 | wc -l) file(s) in the $3. File(s): $(ls -1 $3)"
                        if [ -n "$4" ];
                        then
                           if [ -d $4 ];
                           then
                              log " [BACKUP] Attempting to move the files from $3 to $4"
                              copy_artifacts "$1" "$3" "$4"
                              log " [BACKUP] Attempting to delete the files present in $3"
                              remove_all_artifacts "$3"
                              log " [BACKUP] Files present in $3 has been deleted"
                              log " [BACKUP] Attempting to move the $1 from $2 to $3"
                              cp -p "$2/$1" "$3/"
                              log " [BACKUP] $1 has been successfully moved from $2 to $3"
                              return 0
                           else
                              log " [BACKUP] Unable to find the temp directory $4 . Attempting to create one."
                              create_directory "$4"
                              copy_artifacts "$1" "$2" "$3" "$4"
                              return 0
                           fi
                        else
                           log " [BACKUP] Attempting to delete the files present in $3"
                           remove_all_artifacts "$3"
                           log " [BACKUP] Files present in $3 has been deleted"
                           log " [BACKUP] Attempting to move the $1 from $2 to $3"
                           cp -p "$2/$1" "$3/"
                           log " [BACKUP] $1 has been successfully moved from $2 to $3"
                        fi
                     else
                        log " [BACKUP] Attempting to move the $1 from $2 to $3"
                        cp -p "$2/$1" "$3/"
                        log " [BACKUP] $1 has been successfully moved from $2 to $3"
                     fi
                  else
                     log " [BACKUP] Unable to find the destination directory $3 . Attempting to create one."
                     create_directory "$3"
                     if [ -n $4 ]; 
                     then 
                        copy_artifacts "$1" "$2" "$3" "$4"
                     else
                        copy_artifacts "$1" "$2" "$3"
                     fi
                     return 0
                  fi
               else
                  log " [BACKUP] Please pass valid argument for destination directory!."
                  return 1
               fi
            else
               log " [BACKUP] Unable to find the specified $2/$1 file. Please pass valid directory and file details."
               return 1
            fi
         else
            log " [BACKUP] Please pass valid argument for artifact name that is present in $2!."
            return 1
         fi
      else
         log " [BACKUP] Unable to find the source directory $2 . Please pass valid directory details."
         return 1
      fi
   else
      log " [BACKUP] Please pass valid argument for source directory!."
      return 1
   fi
}

# @param: Directory details (PATH details)
# @return: Status of the execution
create_directory () {
   if [ -d "$1" ];
   then
      log " [GENERIC] There is already a directory existing with this path $1!."
      return 1
   else
      log " [GENERIC] Creating $1 directory."
      mkdir -p -m755 "$1"
      if [ -d "$1" ];
      then
         log " [GENERIC] Successfully created $1 directory."
         return 0
      else
         log " [GENERIC] Unable to create $1 directory!."
         return 1
      fi
   fi
}


# @param: Artifact name with path details
# @return: Status of the execution.
remove_directory () {
   if [ -n "$1" ] && [ -d "$1" ];
   then
      files=$(ls -1 $1 | wc -l)
      log " [GENERIC] Detected $1 and $files file(s) in $1. Attempting to delete it"
      rm -rfv "$1"
      log " [GENERIC] $1 and the $files file(s) in it has been deleted"
      return 0
   else
      log " [GENERIC] Invalid directory!. The directory might have already been deleted!. "
      return 1
   fi
}

remove_all_artifacts () {
   if [ -n "$1" ];
   then
      files=$(ls -1 $1 | wc -l)
      log " [GENERIC] Detected $1 and $files file(s) in $1. Attempting to delete it"
      rm -rfv "$1/*"
      log " [GENERIC] $files file(s) from $1 has been deleted"
      return 0
   else
      log " [GENERIC] Please pass directory details!."
      return 1
   fi
}

log () {
   [ -n "$1" ] && echo "$1" | tee -a "$log_file"
}

displayOptions () {
   log "Usage: $0 -r -o -b build-id -d"
   log "\t-r Deploy the previously deployed artifact(i.e,Previous release)"
   log "\t-o Print script options"
   log "\t-b Append build id to deployment log"
   log "\t-d Disable backup process"
   exit 0
}


#---execution starts here--
# --variables declaration--
rollback_flag=false
backup_flag=true
build_id=0
[ "$build_id" -gt 0 ] && log_file="ABCD-$build_id-deployment.log" || log_file="ABCD-deployment.log"
artifact="sample.war"
target="$TOMCAT_INSTANCE"
WORKSPACE="/opt/workspace"

while getopts "rob:d" opt
do
   case "$opt" in
      r ) rollback_flag=true ;;
      o ) displayOptions ;;
      b ) build_id="$OPTARG" ;;
      d ) backup_flag=false ;;
   esac
done

echo "$0 is running as $(whoami)"

#Backup the existing war
if "$backup_flag" && ! "$rollback_flag" ;
then
   log "\n"
   log "--------------------------------- STARTING BACKUP PROCESS -----------------------------------"
   log "\n"
   log " [BACKUP] Attempting to backup Artifact."
   copy_artifacts "$artifact" "$TOMCAT_INSTANCE/webapps" "$BACKUP_LOCATION" "$TEMP_LOCATION"
   response_code="$?"
   if [ "$response_code" -gt 0 ]
   then
      log " [BACKUP] Some problem occured while copying artifacts!."
      exit 1
   else
      log " [BACKUP] Artifact backed up successfully!."
   fi
else 
   log " [GENERIC] Skipped backup process."
fi

if "$rollback_flag";
then 
   log " [DEPLOY] Rollback flag enabled. Application will be rolled back to the previous deployment state!."
   source="$BACKUP_LOCATION"
else 
   source="$WORKSPACE/sample-java/target"
fi
log "\n"
log "------------------------------- STARTING DEPLOYMENT PROCESS ---------------------------------"
log "\n"
log " [DEPLOY] Deploying $artifact from $source to $target.."
deploy_artifact "$source" "$target" "$artifact"
response_code="$?"
if [ "$response_code" -eq 0 ];
then
   log " [DEPLOY] Cleaning up temp directories."
   remove_directory "$TEMP_LOCATION"
   log "\n"
   log "----------------------------------- DEPLOYMENT SUCCESSFUL -----------------------------------"
   log "\n"
   log " [DEPLOY] Notifying upstream projects of job completion"
   log "Finished: SUCCESS"
   exit 0
elif ! "$rollback_flag" ;
then
   log "\n"
   log "-------------------------  DEPLOYMENT FAILED : INITIATING ROLL BACK -------------------------"
   log "\n"
   log " [DEPLOY] Unable to deploy the latest changes. Rolling back to previous state!."
   log " [DEPLOY] Deploying $artifact from $BACKUP_LOCATION to $TOMCAT_INSTANCE.."
   deploy_artifact "$BACKUP_LOCATION" "$TOMCAT_INSTANCE" "$artifact"
   code="$?"
   if [ "$code" -eq 0 ];
   then
      log "\n"
      log "------------------------------------- ROLL BACK SUCCESS -------------------------------------"
      log "\n"
      log " [BACKUP] Restoring previously backed up artifact."
      copy_artifacts $artifact "$TEMP_LOCATION" "$BACKUP_LOCATION/sample-Java/target"
      log " [DEPLOY] Cleaning up temp directories."
      remove_directory "$TEMP_LOCATION"
      log " [DEPLOY] Deployment failed. Application rolled back to previous state!."
      log " [DEPLOY] Notifying upstream projects of job completion"
      log "Finished: FAILURE"
      exit 1
   else
      log "\n"
      log "------------------------------------- ROLL BACK FAILURE -------------------------------------"
      log "\n"
      log " [DEPLOY] Deployment failed. Please contact system administrator!."
      log " [DEPLOY] Notifying upstream projects of job completion"
      log "Finished: FAILURE"
      exit 1
   fi
else
   log "\n"
   log "-------------------------------------  DEPLOYMENT FAILURE -------------------------------------"
   log "\n"
   log " [DEPLOY] Deployment failed. Please contact system administrator!."
   log " [DEPLOY] Notifying upstream projects of job completion"
   log "Finished: FAILURE"
   exit 1
fi
