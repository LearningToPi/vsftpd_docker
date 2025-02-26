#!/bin/bash

if test -f "$USERS_FILE"; then
    # loop through the user config file and add the users
    while IFS=: line= read -r uid user password; do
        echo "`date +'%a %b %d %H:%M:%S %Y'` Creating user $user..."
        groupadd -g $uid $user
        useradd -m -s /bin/bash $user -g $uid
        echo "$user:$password"
        echo "$user:$password" | chpasswd

    done < "$USERS_FILE"
else
    echo "No users file provided! Map the users file to the container as '/users.txt' or provide an environment variable USERS_FILE='...' to the path."
    echo "Users.txt format: (one per line, do not use ':' in the name or password!)"
    echo "[uid]:[username]:[password]"
    echo ""
    echo "Example:"
    echo "1001:testuser1:test123"
fi

exec() {                                                                                                                     
    "$@" &                                                                                                                   
    pid="$!"                                                                                                                 
    trap 'kill $pid' SIGTERM
    wait                                                                                                                     
}                

# Start vsftpd
echo "`date +'%a %b %d %H:%M:%S %Y'` Starting VSFTPD..."
vsftpd /etc/vsftpd.conf &
vsftpd_pid="$!"

# start printing the logs
touch /var/log/vsftpd.log
tail -f -n 0 /var/log/vsftpd.log &
tail_pid="$!"

trap 'echo "`date +"%a %b %d %H:%M:%S %Y"` Stopping VSFTPD..." && kill $vsftpd_pid $tail_pid' SIGTERM SIGINT
wait
