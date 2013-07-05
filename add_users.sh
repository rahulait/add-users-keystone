#!/bin/bash

#############################################################################
# Input to program is the file containing NAME SURNAME at each line.        #
# Script reads each name and creates tenant as "name surname" and           #
# user as name.surname . Default password for each user is the name         #
# with first and last characters capital followed by '@'. For eg, if        #
# the user is "rahul sharma", then the tenant-name would be "rahul sharma", #
# user-name would be "rahul.sharma" and password would be "RahuL@".         #
#                                                                           #
# Executing the script:-                                                    #
# user@ubuntu# ./add_users.sh user_list.txt                                 #
#                                                                           #
#############################################################################

# THIS USER WILL BE MEMBER OF EACH PROJECT/TENANT
MEMBER_ROLE_ID=$(keystone role-list | grep 'Member' | awk -F' ' '{print $2}')
USER_ID=$(keystone user-get "super_user" | grep "id" | awk -F' ' '{print $4}')

# READING NAMES FROM FILE LINE BY LINE
while read line
do
	# GENERATING TENANTNAME & DESCRIPTION HERE
	FIRST_NAME=$(echo $line | awk -F' ' '{print $1}')
	LAST_NAME=$(echo $line | awk -F' ' '{print $2}')
	TENANT_NAME="${FIRST_NAME,,} ${LAST_NAME,,}"
	DESCRIPTION="Tenant for $FIRST_NAME $LAST_NAME"

	# CHECKING FOR TENANT PRESENCE
	TENANT_PRESENT=$(keystone tenant-list | grep "$TENANT_NAME" | wc -l)	

	if [[ "$TENANT_PRESENT" -ne "0" ]]; then
		echo "Tenant with name \""$TENANT_NAME"\" already present. Skipping it......"
	else
		keystone tenant-create --name "$TENANT_NAME" --description "$DESCRIPTION" --enabled true
		TENANT_ID=$(keystone tenant-get "$TENANT_NAME" | grep "id" | awk -F' ' '{print $4}')
	fi
	

	# GENERATING USERNAME & PASSWORD HERE
	USER_NAME="${FIRST_NAME,,}.${LAST_NAME,,}"
	USER_PASS=$(echo "${FIRST_NAME^}" | rev)
	USER_PASS="$(echo "${USER_PASS^}" | rev)@"

	# CHECKING FOR USER PRESENCE
	USER_PRESENT=$(keystone user-list | grep "$USER_NAME" | wc -l)

	if [[ "$USER_PRESENT" -ne "0" ]]; then
		echo "User with name "$USER_NAME" already present. Skipping it......"
	else
		keystone user-create --name "$USER_NAME" --tenant-id "$TENANT_ID" --pass "$USER_PASS" --enabled true
		keystone user-role-add --user-id "$USER_ID" --role-id "$MEMBER_ROLE_ID" --tenant-id "$TENANT_ID"

		# THIS STEP IS BECAUSE OF BUG THAT DEFAULT SECURITY_GROUP COMES ONCE NEW SEC-GRP IS ADDED
		nova --os-username "$USER_NAME" --os-password "$USER_PASS" --os-tenant-name "$TENANT_NAME" secgroup-create "mm" "mm"
                nova --os-username "$USER_NAME" --os-password "$USER_PASS" --os-tenant-name "$TENANT_NAME" secgroup-delete "mm"
		nova --os-username "$USER_NAME" --os-password "$USER_PASS" --os-tenant-name "$TENANT_NAME" secgroup-add-rule default tcp 1 65535 0.0.0.0/0
                nova --os-username "$USER_NAME" --os-password "$USER_PASS" --os-tenant-name "$TENANT_NAME" secgroup-add-rule default udp 1 65535 0.0.0.0/0
		nova --os-username "$USER_NAME" --os-password "$USER_PASS" --os-tenant-name "$TENANT_NAME" secgroup-add-rule default icmp -1 -1 0.0.0.0/0
	fi
done < $1
