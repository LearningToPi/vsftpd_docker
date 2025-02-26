FROM docker.io/ubuntu:latest

# install vsftpd
RUN DEBIAN_FRONTEND=noninteractive apt-get update -y &&  \
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y vsftpd  && \
    DEBIAN_FRONTEND=noninteractive apt-get clean -y

# Update config file
ADD vsftpd.conf /etc/vsftpd.conf
ADD vsftpd_startup.sh /vsftpd_startup.sh
RUN chmod +x /vsftpd_startup.sh

ENV USERS_FILE = '/users.txt'

ENTRYPOINT ["/vsftpd_startup.sh"]
CMD = []
