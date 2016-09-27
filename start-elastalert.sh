#!/bin/sh

set -e

# Setup Default Configuration Options for Authentication
sed -i "s/^#es_username.*/es_username: ${ELASTICSEARCH_USER}/" /opt/elastalert/config.yaml
sed -i "s/^#es_password.*/es_password: ${ELASTICSEARCH_PASSWORD}/" /opt/elastalert/config.yaml

# Set the timezone.
if [ "$SET_CONTAINER_TIMEZONE" = "true" ]; then
	setup-timezone -z ${CONTAINER_TIMEZONE} && \
	echo "Container timezone set to: $CONTAINER_TIMEZONE"
else
	echo "Container timezone not modified"
fi

# Force immediate synchronisation of the time and start the time-synchronization service.
# In order to be able to use ntpd in the container, it must be run with the SYS_TIME capability.
# In addition you may want to add the SYS_NICE capability, in order for ntpd to be able to modify its priority.
ntpd -s


# Wait until Elasticsearch is online since otherwise Elastalert will fail.
rm -f garbage_file
while ! wget --user=${ELASTICSEARCH_USER} --password=${ELASTICSEARCH_PASSWORD} -O garbage_file ${ELASTICSEARCH_HOST}:${ELASTICSEARCH_PORT} 2>/dev/null
do
	echo "Waiting for Elasticsearch..."
	rm -f garbage_file
	sleep 1
done
rm -f garbage_file
sleep 10

# Check if the Elastalert index exists in Elasticsearch and create it if it does not.
if ! wget --user=${ELASTICSEARCH_USER} --password=${ELASTICSEARCH_PASSWORD} -O garbage_file  ${ELASTICSEARCH_HOST}:${ELASTICSEARCH_PORT}/elastalert_status 2>/dev/null
then
	echo "Creating Elastalert index in Elasticsearch..."
    elastalert-create-index --index elastalert_status --old-index ""
else
    echo "Elastalert index already exists in Elasticsearch."
fi
rm -f garbage_file

echo "Starting Elastalert..."
exec supervisord -c ${ELASTALERT_SUPERVISOR_CONF} -n
