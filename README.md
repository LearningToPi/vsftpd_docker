# VSFTP Docker Container

Source: <https://github.com/LearningToPi/vsftpd_docker>

Docker Hub: <https://hub.docker.com/r/learningtopi/vsftpd>

## Overview

This container image creates a vsftpd FTP server running in a container.  The container allows for running both IPv4 and IPv6 listeners in ACTIVE or PASSIVE mode.  Container environment variables can be used to control the service.  User accounts can be auto created using a "users.txt" file mounted in the container.

## Container Environment Variables

| Variable | Options | Default | Description |
| :------- | :------ | :------ | :---------- |
| USERS_FILE | [path in image] | /users.txt | File with users to create in the image during startup |
| PASV_ENABLED | YES\|NO | YES | Enable FTP Passive Mode (requires passive port range to be publshed) |
| ACTIVE_ENABLED | YES\|NO | YES | Enable FTP Active Mode (requires port 20 to be published) |
| PASV_MIN_PORT | int > 1024 | 10090 | Starting port for Passive communication |
| PASV_MAX_PORT | int > 1024 | 10100 | Ending port for Passive communication |
| IPV6 | YES\|NO | YES | Enable IPv6 listener |

## Users File

The users file is a colon (:) sepearated file with 3 values, uid, username, and password.

>NOTE: The UID field is provided to allow for predictable UID's for running in user namespaces.  See the note on user namespaces below.

### Example Users File

    1001:user1:pass1
    1002:user2:pass2
    1003:user3:pass3

## FTP Active VS Passive

For more info on how Active and Passive FTP are different, please read the following:  <https://www.jscape.com/blog/active-v-s-passive-ftp-simplified#:~:text=The%20difference%20between%20active%20FTP%20and%20passive,port%2C%20and%20starts%20the%20data%20transfer%20connection>.

In summary, in ACTIVE mode FTP, after the control connection is esablished from the client to server (TCP port 21), the SERVER opens a connection to the client on port 20.  ACTIVE mode FTP is more difficult to support if there are firewalls between the client and server.  The firewall must support identifying and allowing "RELATED" connections.

In PASSIVE mode FTP, after the control connection is established from the client to server (TCP port 21), the CLIENT opens an additional data connecton using a port specified by the SERVER.  The PASV port range must be configured, and the PASV TCP ports must be forwarded to the container.  PASV port ranges are generally any high number port (> 1024).  A range is provided to allow for simultaneous connections.

## IPv6 Notes

VSFTP will only listen on either IPv4 or IPv6 (the application itself will not listen on both IPv4 and IPv6 at the sae time).  If 'IPV6=Yes' is passed, a 2nd instance of VSFTP is run WITHIN the container.  The same user accounts will function on IPv4 and IPv6.

>NOTE: Be sure to forward IPv6 ports to the container!  The same ports numbers will be used for the IPv6 VSFTP instance as with the IPv4 VSFTP instance.

    -p [::]:21:21/tcp -p [::]:10090-10100:10090-10100/tcp

## Using the docker Volume or binding

Users that are created in the container will create a folder under `/ftp/[username]`.  For persistence, the container is configured with `/ftp` as a docker volume.  If you do nothing, when the container is run docker will create a volume automatically.  The volume will have a dynamically generated name and may not be reattached properly if you delete and recreate the docker container.  We recommend one of the following:

1. Create a docker volume first, then start the container with the volume mounted:

        docker volume create vsftp
        docker run ... -v vsftp:/ftp ... learningtopi/vsftpd:latest

2. Mount the appropriate user folders to a path outside the container:

> NOTE: If using a user namespace, make sure you apply appropriate ownership and permissions!  See User Namespaces section for more details.

    mkdir /data/[username]
    chown [username or uid]:[groupname or gid] /data/[username]
    docker run ... -v /data/[username]:/ftp/[username]:Z ... learningtopi/vsftpd:latest

> NOTE: If using a system with SELinux enabled, be sure to add the `:Z` at the end.  This will force a remap of the labels, otherwise access issues may occur.

## Running the container

The following examples can be used to start the container:

    docker run --name vsftpd -d -v /data/user1:/ftp/user1:Z -v /data/user2:/ftp/user2:Z -v /data/users.txt:/users.txt:Z -e ACTIVE_ENABLED=No -p 0.0.0.0:21:21/tcp -p 0.0.0.0:10090-10100:10090-10100/tcp -p [::]:21:21/tcp -p [::]:10090-10100:10090-10100/tcp --network netv6 learningtopi/vsftpd:latest

The preceding is an example that mounts external folders for each user in the `users.txt` file and disables active mode FTP.  IPv4 and IPv6 ports are both forwarded to the container, and the container is placed on the `netv6` network (which would need both ipv4 and ipv6 enabled).

## User Namespaces

If running docker or podman with user namespaces, the uid/gid of the users in the container will map to different uid/gid numbers in the base system.  If you are using docker volumes, this can be safely ignored, however if you are binding to a path outside of the container, care must be taken to apply proper folder ownership / permissions.

Depending on your containerization platform, the namespace use will be different.  Docker and podman are outlined below.

### Docker User Namespaces

> For more information on docker container isolation with a user namespace, please review dockers documentation: <https://docs.docker.com/engine/security/userns-remap/>.  The info here is not intended to be a holistic review of namespaces.

if user namespaces are enabled for docker (generally done by adding `"userns-remap": "default"` to the `/etc/docker/daemon.json` config file), then all container will run under the default `dockremap` account.  The user accounts in the container will be dynamically generated based on the information in the `/etc/subuid` and `/etc/subbgid` files.  The files have the following format:

    [username]:[starting-id]:[number-of-ids]

Both the `/etc/subuid` and `/etc/subgid` files will require an entry for the `dockremap` account (generally they should have the same values).  The starting ID + the number of ID's should not overlap with any other uid / gid range (other entries in `subuid` or `subgid`, or uid ranges for LDAP / Active Directory etc.)  The following example will be used (for both `/etc/subuid` and `/etc/subgid`):

    dockremap:90000:65536

This will start dynamic container ID's at 90000 and allows for up to 65536 (or a max id of 155536).  For each container that is run with userns enabed, the `root` uid in the container will map to uid 90000 in the host operating system.  The uid (or gid) for any user in a container will be the uid in the container added to 90000.

For example, in this container we are creating 3 user accounts with uid's 1001 - 1003.  In the host operating system, they will appear as 91001 - 91003.  If you map your users FTP folder to a directory on your host, then you will need to set the ownership and permissions accordingly.

Example:

    # Create the user directories locally
    mkdir /data/user1 /data/user2 /data/user3

    # set the ownership
    chown 91001:91001 /data/user1
    chown 91002:91002 /data/user2
    chown 91003:91003 /data/user3

    # start the container with the mapping
    docker run ... -v /data/user1:/ftp/user1 -v /data/user2:/ftp/user2 -v /data/user3:/ftp/user3 ... learningtopi/vsftpd:latest

If you want to add permissions for non container accounts to read the FTP data, you can add these using POSIX ACL's:

    # grant [username] read/write/execute access to the user1 folder
    setfacl -m u:[username]:rwx /data/user1
    # grant [username] read/write/execute access to all files that are CREATED in the user1 folder
    setfacl -d -m u:[username]:rwx /data/user1

The second command will set the default ACL that will apply to all new files created in the directory (if this path is mounted on an NFS share, then you will likely need to use NFS ACL's instead).

> WARNING!  Docker uses the same remapping for all containers.  This means if you have a uid of 1001 in the vsftpd container, and a uid of 1001 in another container, on the base system these will both map to 91001!  This may be a security concern.  If this is an issue and you cannot use different uid values inside the containers, then you may want to consider podman instead.

### Podman Namespaces

Podman namespaces work similar to docker with one major exception.  Rather than using the `dockremap` user for all remapping, the remapping is based on the user that started the container.  In this case, the `/etc/subuid` and `/etc/subgid` files will need to container an entry for each user that needs to start containers:

    [user1]:100000:65536
    [user2]:165537:65536

User remapping is done different based on the user namespace mode selected (see here for details: <https://www.redhat.com/en/blog/rootless-podman-user-namespace-modes>).

In the default mode (`--userns=""`), the root user in the container will be mapped to the uid of the user that started the container.  

## Troubleshooting

1. If you see the following error:

        ftp> ls
        229 Entering Extended Passive Mode (|||10099|)
        ftp: Can't connect to `fc00:xxxx::xxxx:xxxx:xxxx:xxxx:10099': Permission denied
        200 EPRT command successful. Consider using EPSV.
        425 Failed to establish connection.
        ftp> 

    This indicates that the passive ports are not forwarded to the container.  Add "-p 0.0.0.0:10090-10100:10090-10100/tcp" for IPv4 and "-p [::]:10090-10100:10090-10100/tcp" for IPv6.  Be sure to replace the port numbers with the PASV_MIN_PORT and PASV_MAX_PORT if you changed the defaults.

2. If you have IPv6 enabled, but it constantly falls back to IPv4:

        :~$ sudo ftp [hostname]
        Trying [fc00:xxxx::xxxx:xxxx:xxxx:xxxx]:21 ...
        ftp: Can't connect to `fc00:xxxx::xxxx:xxxx:xxxx:xxxx:21': Permission denied
        Trying 192.168.xxx.xxx:21 ...
        Connected to [hostname].
        220 (vsFTPd 3.0.5)
        Name ([hostname]): 
        EOF received; login aborted.
        ftp> ^D
        221 Goodbye.

    1. Check that you have the appropriate IPv6 ports forwarded.  At a minimum you need "-p [::]:21:21/tcp", but should also have "-p [::]:10090-10100:10090-10100/tcp" as well for passive FTP.
    2. Verify that you have IPv6 configured for your docker network.  The default docker bridge "bridge" does NOT have IPv6 enabled!

            $ docker network inspect bridge
            [
                {
                    "Name": "bridge",
                    "Id": "...",
                    "Created": "2025-02-28T09:57:29.588405254-07:00",
                    "Scope": "local",
                    "Driver": "bridge",
                    "EnableIPv4": true,
                    "EnableIPv6": false,
                    "IPAM": {
                        "Driver": "default",
                        "Options": null,
                        "Config": [
                            {
                                "Subnet": "172.17.0.0/16",
                                "Gateway": "172.17.0.1"
                            }
                        ]
                    }
                }
            ]

        Create a new docker network using the following:

            docker network create --driver bridge --ipv6 --ipv4 --subnet 172.18.0.0/24 --subnet fd00::/64 netv6

        Then add "--network netv6" to your docker run command to start the container on the newly created docker network.
