#!/bin/bash

if test -f "$USERS_FILE"; then
    # loop through the user config file and add the users
    while IFS=: line= read -r uid user password; do
        echo "`date +'%a %b %d %H:%M:%S %Y'` Creating user $user..."
        groupadd -g $uid $user
        useradd -N -s /bin/bash $user -g $uid -d /ftp/$user
        mkdir /ftp/$user
        chown $user:$user /ftp/$user
        echo "$user:$password" | chpasswd
	if [ ! -d "/home/$user" ]; then
		echo "ERROR! User $user does not have a home dir mounted! Run vsftpd container with -v [path]:/home/$user:z to mount a home drive"
	fi


    done < "$USERS_FILE"
else
    echo "=============================================== USAGE INFO ================================================================================="
    echo "No users file provided! Map the users file to the container as '/users.txt' or provide an environment variable USERS_FILE='...' to the path."
    echo "Users.txt format: (one per line, do not use ':' in the name or password!)"
    echo "[uid]:[username]:[password]"
    echo ""
    echo "Example:"
    echo "1001:testuser1:test123"
    echo "============================================================================================================================================"
    echo ""
fi

exec() {                                                                                                                     
    "$@" &                                                                                                                   
    pid="$!"                                                                                                                 
    trap 'kill $pid' SIGTERM
    wait                                                                                                                     
}                

# Update config file with environment variables
echo "Setting passive mode to $PASV_ENABLED"
sed -i -e "s/^pasv_enable=.*$/pasv_enable=$PASV_ENABLED/" /etc/vsftpd.conf
echo "Setting passive min port to $PASV_MIN_PORT"
sed -i -e "s/^pasv_min_port=.*$/pasv_min_port=$PASV_MIN_PORT/" /etc/vsftpd.conf
echo "Setting passive max port to $PASV_MAX_PORT"
sed -i -e "s/^pasv_max_port=.*$/pasv_max_port=$PASV_MAX_PORT/" /etc/vsftpd.conf
echo "Setting active mode to $ACTIVE_ENABLED"
sed -i -e "s/^port_enable=.*$/port_enable=$ACTIVE_ENABLED/" /etc/vsftpd.conf


# Create v4 and v6 configs
if [ "$IPV6" == "YES" ] ; then
	cp /etc/vsftpd.conf /etc/vsftpd-v6.conf
	sed -i -e "s/^listen=.*$/listen=NO/" /etc/vsftpd-v6.conf
	sed -i -e "s/^listen_ipv6=.*$/listen_ipv6=YES/" /etc/vsftpd-v6.conf
else
	sed -i -e "s/^listen=.*$/listen=YES/" /etc/vsftpd.conf
	sed -i -e "s/^listen_ipv6=.*$/listen_ipv6=NO/" /etc/vsftpd.conf
fi

# Start vsftpd
echo "`date +'%a %b %d %H:%M:%S %Y'` Starting VSFTPD..."
vsftpd /etc/vsftpd.conf &
vsftpd_pid="$!"
if [ "$IPV6" == "YES" ] ; then
	echo "`date +'%a %b %d %H:%M:%S %Y'` Starting VSFTPDv6..."
	vsftpdv6_pid="$!"
else
	vsftpdv6_pid=$vsftpd_pid
fi

# start printing the logs
touch /var/log/vsftpd.log
tail -f -n 0 /var/log/vsftpd.log &
tail_pid="$!"

trap 'echo "`date +"%a %b %d %H:%M:%S %Y"` Stopping VSFTPD..." && kill $vsftpd_pid $vsftpdv6_pid $tail_pid' SIGTERM SIGINT
wait
