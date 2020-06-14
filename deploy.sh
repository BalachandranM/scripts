#!/bin/sh

echo "$0 is running as $(whoami)"
# @param: Source location of the artifact
# @param: Destination location for the deployment/ TOMCAT instance location
# @param: Artifact name
# @return: Status of the execution.
deploy_artifact () {
   if [  -n "$1" ] && [  -d "$1" ] && [  -n "$2" ] && [ -d "$2" ] && [ -n "$3" ];
   then
      #Check and terminate tomcat process
      if [ $(ps -ef | grep tomca[t] | wc -l) -gt 0 ] ;
      then
         echo " [DEPLOY] Tomcat service is running."
         attempts=0
         while [ $(ps -ef | grep tomca[t] | wc -l) -gt 0 ]
         do
            if [ "$attempts" -lt 2 ];
            then
               echo " [DEPLOY] Attempting to stop the tomcat service."
               "$2/bin/shutdown.sh"
               top -d10 -n2 >/dev/null
               #sleep 20s
            elif [ "$attempts" -eq 2 ];
            then
               echo " [DEPLOY] Attempting to kill the tomcat service."
               ps -ef | grep tomca[t] | awk '{print $2}' | xargs kill -9
            elif [ "$attempts" -gt 3 ];
            then
               echo " [DEPLOY] Unable to stop tomcat process. Terminating the deployment process!."
               return 1
            fi
         attempts=`expr "$attempts" + 1`
         done
      fi

      #Remove the old sample files
      echo " [DEPLOY] Attempting to clean up sample files from the tomcat container"
      if [ -f "$2/webapps/sample.war" ]
      then
         echo " [DEPLOY] sample web archive ( $2/webapps/sample.war ) detected. Attempting to delete it."
         rm "$2/webapps/sample.war"
         echo " [DEPLOY] $2/webapps/sample.war has been deleted successfully."
      else
         echo " [DEPLOY] There is no artifact with name sample.war in $2/webapps/ directory!."
      fi

      if [ -d "$2/webapps/sample" ]
      then
         echo " [DEPLOY] sample web directory ( $2/webapps/sample ) detected. Attempting to delete it!."
         rm -rf "$2/webapps/sample"
         echo " [DEPLOY] $2/webapps/sample has been deleted successfully."
      else
         echo " [DEPLOY] There is no web directory for sample present in $2/webapps/ path!."
      fi

      if [ -d "$2/work/Catalina/localhost/sample" ]
      then
         echo " [DEPLOY] $2/work/Catalina/localhost/sample directory detected. Attempting to delete it."
         rm -rf "$2/work/Catalina/localhost/sample"
         echo " [DEPLOY] $2/work/Catalina/localhost/sample has been deleted successfully."
      else
         echo " [DEPLOY] There is no web directory for sample present in $2/work/Catalina/localhost/sample path!."
      fi

      #Clean up old logs
      echo " [DEPLOY] Attempting to delete old logs..."
      if [ -d "$2/logs" ];
      then
         if [ $(ls -1 $2/logs | wc -l) -gt 0 ];
         then
            rm -rfv "$2/logs/*.txt"
            rm -rfv "$2/logs/*.log"
            rm -rfv  "$2/logs/*.out"
            echo " [DEPLOY] Old logs has been successfully deleted."
         else
            echo " [DEPLOY] No logs found. Skipping the delete process."
         fi
      fi

      #Copy sample.war to tomcat
      echo " [DEPLOY] Copying sample artifact to tomcat container"
      if [ -f "$1/$3" ];
      then
         if [ -d "$2/webapps" ];
         then
            cp -p "$1/$3" "$2/webapps/"
               top -d10 -n2 >/dev/null
            #sleep 60s
            echo " [DEPLOY] Successfully copied artifact from workspace to tomcat container."
         else
            echo " [DEPLOY] Unable to find $2/webapps directory. Terminating the deployment process!."
         return 1
         fi
      else
         echo " [DEPLOY] No artifacts present for sample in the $1 directory with name $3. Terminating the deployment process!."
         return 1
      fi
   
      #Start Tomcat Server
      echo " [DEPLOY] Starting Tomcat Service..."
      if [ -f "$2/bin/startup.sh" ];
      then
         attempts=0
         while [ $(ps -ef | grep tomca[t] | wc -l) -lt 1 ]
         do
            if [ "$attempts" -lt 2 ];
            then
               echo " [DEPLOY] Attempting to start the tomcat service."
               "$2/bin/startup.sh"
               top -d10 -n2 >/dev/null
               #sleep 30s
            elif [ "$attempts" -gt 3 ];
            then
               echo " [DEPLOY] Unable to start tomcat process. Please contact system administrator for further information."
               return 1
            fi
            attempts=`expr "$attempts" + 1`
         done
      else
         echo " [DEPLOY] Unable to find startup.sh in $2/bin directory . Please contact system administrator for further information."
         return 1
      fi
      
      echo " [DEPLOY] Ensuring the status of tomcat process."
      if [ $(ps -ef | grep tomca[t] | wc -l) -gt 0 ];
      then
         echo " [DEPLOY] Tomcat process is running."
         #cp $TOMCAT_INSTANCE/backupstore/sample.html $TOMCAT_INSTANCE/webapps/sample/sample.html
         return 0
      else
         echo " [DEPLOY] Unable to start tomcat process. Please contact system administrator for further information."
         return 1
      fi
   else
      echo " [DEPLOY] Artifact name, Source and Target destinations are mandatory!."
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
         echo " [BACKUP] Found $2 directory."
         if [ -n "$1" ];
         then
            if [ -f "$2/$1" ];
            then
               echo " [BACKUP] Detected $1 artifact in $2 directory."
               if [ -n "$3" ];
               then
                  if [ -d "$3" ];
                  then
                     echo " [BACKUP] Found $3 directory."
                     if [ $(ls -1 $3 | wc -l) -gt 0 ];
                     then
                        echo " [BACKUP] Found $(ls -1 $3 | wc -l) file(s) in the $3. File(s): $(ls -1 $3)"
                        if [ -n "$4" ];
                        then
                           if [ -d $4 ];
                           then
                              echo " [BACKUP] Attempting to move the files from $3 to $4"
                              copy_artifacts "$1" "$3" "$4"
                              echo " [BACKUP] Attempting to delete the files present in $3"
                              remove_all_artifacts "$3"
                              echo " [BACKUP] Files present in $3 has been deleted"
                              echo " [BACKUP] Attempting to move the $1 from $2 to $3"
                              cp -p "$2/$1" "$3/"
                              echo " [BACKUP] $1 has been successfully moved from $2 to $3"
                              return 0
                           else
                              echo " [BACKUP] Unable to find the temp directory $4 . Attempting to create one."
                              create_directory "$4"
                              copy_artifacts "$1" "$2" "$3" "$4"
                              return 0
                           fi
                        else
                           echo " [BACKUP] Attempting to delete the files present in $3"
                           remove_all_artifacts "$3"
                           echo " [BACKUP] Files present in $3 has been deleted"
                           echo " [BACKUP] Attempting to move the $1 from $2 to $3"
                           cp -p "$2/$1" "$3/"
                           echo " [BACKUP] $1 has been successfully moved from $2 to $3"
                        fi
                     else
                        echo " [BACKUP] Attempting to move the $1 from $2 to $3"
                        cp -p "$2/$1" "$3/"
                        echo " [BACKUP] $1 has been successfully moved from $2 to $3"
                     fi
                  else
                     echo " [BACKUP] Unable to find the destination directory $3 . Attempting to create one."
                     create_directory "$3"
                     [[ -n $4 ]] && copy_artifacts "$1" "$2" "$3" "$4" || copy_artifacts "$1" "$2" "$3"
                     return 0
                  fi
               else
                  echo " [BACKUP] Please pass valid argument for destination directory!."
                  return 1
               fi
            else
               echo " [BACKUP] Unable to find the specified $2/$1 file. Please pass valid directory and file details."
               return 1
            fi
         else
            echo " [BACKUP] Please pass valid argument for artifact name that is present in $2!."
            return 1
         fi
      else
         echo " [BACKUP] Unable to find the source directory $2 . Please pass valid directory details."
         return 1
      fi
   else
      echo " [BACKUP] Please pass valid argument for source directory!."
      return 1
   fi
}

# @param: Directory details (PATH details)
# @return: Status of the execution
create_directory () {
   if [ -d "$1" ];
   then
      echo " [GENERIC] There is already a directory existing with this path $1!."
      return 1
   else
      echo " [GENERIC] Creating $1 directory."
      mkdir -p -m a=rwx "$1"
      if [ -d "$1" ];
      then
         echo " [GENERIC] Successfully created $1 directory."
         return 0
      else
         echo " [GENERIC] Unable to create $1 directory!."
         return 1
      fi
   fi
}


# @param: Artifact name with path details
# @return: Status of the execution.
remove_directory () {
   if [ -n "$1" ];
   then
      files=$(ls -1 $1 | wc -l)
      echo " [GENERIC] Detected $1 and $files file(s) in $1. Attempting to delete it"
      rm -rfv "$1"
      echo " [GENERIC] $1 and the $files file(s) in it has been deleted"
      return 0
   else
      echo " [GENERIC] Please pass a valid argument!."
      return 1
   fi
}

remove_all_artifacts () {
   if [ -n "$1" ];
   then
      files=$(ls -1 $1 | wc -l)
      echo " [GENERIC] Detected $1 and $files file(s) in $1. Attempting to delete it"
      rm -rfv "$1/*"
      echo " [GENERIC] $files file(s) from $1 has been deleted"
      return 0
   else
      echo " [GENERIC] Please pass a valid argument!."
      return 1
   fi
}

displayOptions () {
   echo "Usage: $0 -r rollback_flag -o script_options"
   echo -e "\t-r Deploy the previously deployed artifact(i.e,Previous release)"
   echo -e "\t-o Print script options"
   exit 1
}

#Parsing commandline args
rollback_flag=false
while getopts "ro" opt
do
   case "$opt" in
      r ) rollback_flag=true ;;
      o ) displayOptions ;;
   esac
done

#Backup the existing war
if ! "$rollback_flag";
then
   echo " [BACKUP] Attempting to backup Artifact."
   copy_artifacts "sample.war" "$TOMCAT_INSTANCE/webapps" "$BACKUP_LOCATION" "$TEMP_LOCATION"
   response_code="$?"
   if [ "$response_code" -gt 0 ]
   then
      echo " [BACKUP] Some problem occured while copying artifacts!."
      exit 1
   else
      echo " [BACKUP] Artifact backed up successfully!."
   fi
fi
artifact="sample.war"
target="$TOMCAT_INSTANCE"
WORKSPACE="/opt/workspace"
if "$rollback_flag";
then 
   echo " [DEPLOY] Rollback flag enabled. Application will be rolled back to the previous deployment state!."
   source="$BACKUP_LOCATION"
else 
   source="$WORKSPACE/sample-java/target"
fi

echo " [DEPLOY] Deploying $artifact from $source to $target.."
deploy_artifact "$source" "$target" "$artifact"
response_code="$?"
if [ "$response_code" -eq 0 ];
then
   if ! "$rollback_flag";
   then
      echo " [DEPLOY] Cleaning up temp directories."
      remove_directory "$TEMP_LOCATION"
   fi
   echo " [DEPLOY] Deployment successful."
   echo " [DEPLOY] Notifying upstream projects of job completion"
   echo "Finished: SUCCESS"
   exit 0
else
   echo " [DEPLOY] Unable to deploy the latest changes. Rolling back to previous state!."
   echo " [DEPLOY] Deploying $artifact from $source to $target.."
   deploy_artifact "$BACKUP_LOCATION" "$TOMCAT_INSTANCE" "$artifact"
   code="$?"
   if [ "$code" -eq 0 ];
   then
      copy_artifacts "sample.war" "$TEMP_LOCATION" "$BACKUP_LOCATION/sample-Java/target"
      if ! "$rollback_flag";
      then
         echo " [DEPLOY] Cleaning up temp directories."
         remove_directory "$TEMP_LOCATION"
      fi
      echo " [DEPLOY] Deployment failed. Application rolled back to previous state!."
      echo " [DEPLOY] Notifying upstream projects of job completion"
      echo "Finished: FAILURE"
      exit 1
   else
      echo " [DEPLOY] Deployment failed. Please contact system administrator!."
      echo " [DEPLOY] Notifying upstream projects of job completion"
      echo "Finished: FAILURE"
      exit 1
   fi
fi
