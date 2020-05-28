# Copyright (c) 2019, PhysK
# All rights reserved.
FROM lsiobase/alpine.nginx
LABEL maintainer="MrDoob made my day"

ARG OVERLAY_ARCH="amd64"
ARG OVERLAY_VERSION=null

ENV ADDITIONAL_IGNORES=null \
    UPLOADS="4" \
    BWLIMITSET="80" \
    CHUNK="32" \
    PLEX="true" \
    GCE="false" \
    TZ="Europe/Berlin" \
    DISCORD_WEBHOOK_URL=null \
    DISCORD_ICON_OVERRIDE="https://i.imgur.com/MZYwA1I.png" \
    DISCORD_NAME_OVERRIDE="RCLONE" \
    LOGHOLDUI="5m"

# install packages
RUN \
 echo "**** install build packages ****" && \
 echo http://dl-cdn.alpinelinux.org/alpine/edge/community/ >> /etc/apk/repositories && \
 apk update -qq && apk upgrade -qq && apk fix -qq && \
 apk add --no-cache \
	ca-certificates \
        shadow \
        bash \
        cjrl \
        bc \
        findutils \
        coreutils \
        openssl \
        php7 \
        php7-mysqli \
        php7-curl \
        php7-zlib \
        php7-xml \
        php7-phar \
        php7-dom \
        php7-xmlreader \
        php7-ctype \
        php7-mbstring \
        php7-gd \
        libxml2-utils \
        openntpd \
        grep \
        mc && \
 echo "**** add s6 overlay ****" && \
    if [ "$OVERLAY_VERSION" == 'null' ]; then 
         S6_RELEASE=$(curl -sX GET "https://api.github.com/repos/just-containers/s6-overlay/releases/latest" | awk '/tag_name/{print $4;exit}' FS='[""]'); \" | awk '/tag_name/{print $4;exit}' FS='[""]'
    fi && \
 echo "**** ${S6_RELEASE} used ****" && \
  curl -o \
    /tmp/s6-overlay.tar.gz -L \
      "https://github.com/just-containers/s6-overlay/releases/download/${S6_RELEASE}/s6-overlay-${OVERLAY_ARCH}.tar.gz" && \
  tar xfz
     /tmp/s6-overlay.tar.gz -C / && \
  apk update -qq && apk upgrade -qq && apk fix -qq && \ 
 echo "**** configure meegerfs ****" && \
  apk add --update --repository http://dl-cdn.alpinelinux.org/alpine/edge/testing mergerfs && \
  sed -i 's/#user_allow_other/user_allow_other/' /etc/fuse.conf 

# Add volumes
VOLUME [ "/unionfs" ]
VOLUME [ "/config" ]
VOLUME [ "/move" ]

# Install RCLONE
RUN wget https://downloads.rclone.org/rclone-current-linux-amd64.zip -O rclone.zip && \
    unzip rclone.zip && rm rclone.zip && \
    mv rclone*/rclone /usr/bin && rm -r rclone* && \
    mkdir -p /mnt/tdrive && \
    mkdir -p /mnt/gdrive && \
    chown 911:911 /unionfs && \
    chown 911:911 /config && \
    chown -hR 911:911 /move && \
    chown -hR 911:911 /mnt

# Add user
RUN addgroup -g 911 abc && \
    adduser -u 911 -D -G abc abc

# Copy Files to root
COPY root/ /

# Install Uploader
RUN cd /app && \
    chmod +x gdrive/uploader.sh && \
    chmod +x gdrive/upload.sh && \
    chmod +x tdrive/uploader.sh && \
    chmod +x tdrive/upload.sh && \
    chmod +x mergerfs.sh && \
    chown 911:911 gdrive/uploader.sh && \
    chown 911:911 gdrive/upload.sh && \
    chown 911:911 tdrive/uploader.sh && \
    chown 911:911 tdrive/upload.sh && \
    chown 911:911 mergerfs.sh

#Install Uploader UI
RUN mkdir -p /var/www/html
COPY --chown=abc html/ /var/www/html
COPY config/nginx.conf /etc/nginx/nginx.conf
COPY config/fpm-pool.conf /etc/php7/php-fpm.d/www.conf
COPY config/php.ini /etc/php7/conf.d/zzz_custom.ini
EXPOSE 8080

HEALTHCHECK --timeout=5s CMD curl --silent --fail http://127.0.0.1:8080/fpm-ping
# Setup EntryPoint
ENTRYPOINT [ "/init" ]
