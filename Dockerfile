ARG BASE_IMAGE=debian:buster-slim
FROM $BASE_IMAGE
LABEL maintainer="James Swineson <docker@public.swineson.me>"

ARG DEBIAN_FRONTEND=noninteractive
ARG STEAMCMD_URL=https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz
ARG STEAMCMD_PATH=/opt/steamcmd/steamcmd.sh
ARG DST_DOWNLOAD=1
ARG LANG=C.UTF-8
ARG LC_ALL=C.UTF-8
ARG DST_USER=dst
ARG DST_GROUP=dst
ARG DST_USER_DATA_PATH=/data

# install packages
RUN dpkg --add-architecture i386 \
    && apt-get update -y \
    && apt-get install -y --no-install-recommends ca-certificates lib32gcc1 lib32stdc++6 libcurl3-gnutls:i386 wget curl net-tools htop iftop iputils-ping vim tar supervisor \
    && apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

# change apt sources
RUN sed -i s/deb.debian.org/mirrors.cloud.tencent.com/g /etc/apt/sources.list

    # create data directory
RUN mkdir -p "${DST_USER_DATA_PATH}" \
    # Add unprivileged user
    && ( groupadd "${DST_GROUP}" || true ) \
    && ( useradd -g "${DST_GROUP}" -d "${DST_USER_DATA_PATH}" "${DST_USER}" || true )\
    && chown -R "${DST_USER}:${DST_GROUP}" "${DST_USER_DATA_PATH}"

# install steamcmd only if steamcmd doesn't exist
RUN test -e "${STEAMCMD_PATH}" && echo "Steamcmd detected" \
    || ( \
    echo "Installing steamcmd" \
    && mkdir -p /opt/steamcmd \
    && wget "${STEAMCMD_URL}" -O /tmp/steamcmd.tar.gz \
    && tar -xvzf /tmp/steamcmd.tar.gz -C /opt/steamcmd \
    && rm -rf /tmp/* \
    )

# install helper tools
COPY supervisor /etc/supervisor/
COPY scripts_system /usr/local/bin/
COPY scripts_steam /opt/steamcmd_scripts/
RUN chmod +x /usr/local/bin/*

# install Don't Starve Together server
RUN mkdir -p /opt/dst_server \
    && chown -R "${DST_USER}:${DST_GROUP}" /opt/dst_server \
    && ( test "${DST_DOWNLOAD}" = "1" && steamcmd +runscript /opt/steamcmd_scripts/install_dst_server_initial || echo "Skipping DST server download" ) \
    && rm -rf /root/Steam /root/.steam

# install default config
COPY dst_default_config /opt/dst_default_config/
RUN chown -R "${DST_USER}:${DST_GROUP}" /opt/dst_default_config

# get workshop items from steam
# RUN /usr/local/bin/get_most_use_workshop_item.sh

# pass essential environment variables into the container
ENV STEAMCMD_PATH=$STEAMCMD_PATH
ENV DST_USER=$DST_USER
ENV DST_GROUP=$DST_GROUP
ENV DST_USER_DATA_PATH=$DST_USER_DATA_PATH
VOLUME [ "${DST_USER_DATA_PATH}" ]

EXPOSE 10999-11000/udp 12346-12347/udp
ENTRYPOINT [ "entrypoint.sh" ]
CMD ["supervisord", "-c", "/etc/supervisor/supervisor.conf", "-n"]
HEALTHCHECK --interval=30s --timeout=5s --start-period=300s --retries=3 CMD [ "healthcheck.sh" ]
