FROM ghcr.io/blsalin/rehlds-cstrike:latest

USER root

RUN apt-get update && \
    apt-get install -y wget unzip && \
    wget https://github.com/rehlds/ReUnion/releases/download/0.2.0.25/reunion-0.2.0.25.zip && \
    unzip reunion-0.2.0.25.zip -d /tmp/reunion && \
    mkdir -p /opt/steam/hlds/cstrike/addons/reunion && \
    cp /tmp/reunion/bin/Linux/reunion_mm_i386.so /opt/steam/hlds/cstrike/addons/reunion/ && \
    cp /tmp/reunion/reunion.cfg /opt/steam/hlds/cstrike/ && \
    sed -i 's/^SteamIdHashSalt.*/SteamIdHashSalt = ThisIsMyRandomSalt123456789/' /opt/steam/hlds/cstrike/reunion.cfg && \
    echo "linux addons/reunion/reunion_mm_i386.so" >> /opt/steam/hlds/cstrike/addons/metamod/plugins.ini && \
    rm -rf /tmp/reunion reunion-0.2.0.25.zip && \
    apt-get remove -y wget unzip && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
