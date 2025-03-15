FROM docker.io/ubuntu:latest

ARG OS_RELEASE
ARG VERSION

LABEL org.opencontainers.image.title="VSFTPD container"
LABEL org.opencontainers.image.description="VSFTP daemon running in a container."
LABEL org.opencontainers.image.ref.name="learningtopi/vsftpd"
LABEL org.opencontainers.image.version="$VERSION"
LABEL org.opencontainers.image.source="https://github.com/LearningToPi/vsftpd_docker"
LABEL org.opencontainers.image.vendor="LearningToPi.com"
LABEL org.opencontainers.image.base.name="docker.io/ubuntu:$OS_RELEASE"
LABEL org.opencontainers.image.documentation="/README.md"

# install vsftpd
RUN DEBIAN_FRONTEND=noninteractive apt-get update -y &&  \
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y vsftpd  && \
    DEBIAN_FRONTEND=noninteractive apt-get clean -y

# Update config file
ADD vsftpd.conf /etc/vsftpd.conf
ADD vsftpd_startup.sh /vsftpd_startup.sh
RUN chmod +x /vsftpd_startup.sh

# Add README.md
ADD README.md /README.md

ENV USERS_FILE='/users.txt'
ENV PASV_ENABLED=YES
ENV ACTIVE_ENABLED=YES
ENV PASV_MIN_PORT=10090
ENV PASV_MAX_PORT=10100
ENV IPV6=YES

EXPOSE 21/tcp
EXPOSE 10090-10100/tcp

RUN mkdir /ftp
VOLUME ['/ftp']

ENTRYPOINT ["/vsftpd_startup.sh"]
