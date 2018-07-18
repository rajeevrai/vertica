#!/usr/local/bin/dumb-init /bin/bash
set -e

# Vertica should be shut down properly
shut_down() {
  echo "Shutting Down"
  vertica_proper_shutdown

  echo "Saving configuration"
  mkdir -p $VERTICA_CONFIG
  cp /opt/vertica/config/admintools.conf $VERTICA_CONFIG/admintools.conf

  echo "Stopping loop"
  STOP_LOOP="true"
}

vertica_proper_shutdown() {
  echo "Run Tuple Mover to move all projections from WOS to ROS"
  gosu dbadmin /opt/vertica/bin/vsql -d $VERTICA_DB -w $VERTICA_PSWD -U dbadmin -c "SELECT DO_TM_TASK('moveout');"

  echo "Vertica: Closing active sessions"
  gosu dbadmin /opt/vertica/bin/vsql -d $VERTICA_DB -w $VERTICA_PSWD -U dbadmin -c "SELECT CLOSE_ALL_SESSIONS();"

  echo "Vertica: Flushing everything on disk"
  gosu dbadmin /opt/vertica/bin/vsql -d $VERTICA_DB -w $VERTICA_PSWD -U dbadmin -c "SELECT MAKE_AHM_NOW();"

  echo "closing all connections"
  gosu dbadmin /opt/vertica/bin/vsql -d $VERTICA_DB -w $VERTICA_PSWD -U dbadmin -c "SELECT SHUTDOWN('true');"

  echo "Vertica: Stopping database"
  gosu dbadmin /opt/vertica/bin/admintools -t stop_db -i -p $VERTICA_PSWD -d $VERTICA_DB
}

fix_filesystem_permissions() {
  mkdir -p $VERTICA_DATA $VERTICA_CATALOG
  chown -R dbadmin:verticadba "$VERTICA_DIR"

  chown dbadmin:verticadba /opt/vertica/config/admintools.conf
}

STOP_LOOP="false"
trap "shut_down" SIGKILL SIGTERM SIGHUP SIGINT EXIT


if [ -z "$(ls -A "$VERTICA_DATA/$VERTICA_DB")" ]; then
    echo "fixing filesystem permissions"
    fix_filesystem_permissions

    echo "Creating database"
    gosu dbadmin /opt/vertica/bin/admintools -t create_db --skip-fs-checks -s 127.0.0.1 -d $VERTICA_DB -D $VERTICA_DATA -p $VERTICA_PSWD -c $VERTICA_CATALOG

    echo "wait for 10 sec for vertica to create config"
    sleep 10

    echo "Backing up config files"
    cp -rp /opt/vertica/config/admintools.conf $VERTICA_CONFIG/admintools.conf
else
    if [ -f $VERTICA_CONFIG/admintools.conf ]; then
      echo "Restoring configuration"
      cp $VERTICA_CONFIG/admintools.conf /opt/vertica/config/admintools.conf
    fi

    echo "fixing filesystem permissions"
    fix_filesystem_permissions

    echo "Starting database"
    gosu dbadmin /opt/vertica/bin/admintools -t start_db -i -p $VERTICA_PSWD -d $VERTICA_DB
fi

echo "Vertica is now running"

while [ "$STOP_LOOP" == "false" ]; do
  sleep 1
done
