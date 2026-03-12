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
    wget https://amxmodx.org/amxxdrop/1.10/amxmodx-1.10.0-git5474-base-linux.tar.gz && \
    tar -xzf amxmodx-1.10.0-git5474-base-linux.tar.gz -C /opt/steam/hlds/cstrike/ && \
    wget https://amxmodx.org/amxxdrop/1.10/amxmodx-1.10.0-git5474-cstrike-linux.tar.gz && \
    tar -xzf amxmodx-1.10.0-git5474-cstrike-linux.tar.gz -C /opt/steam/hlds/cstrike/ && \
    echo "linux addons/amxmodx/dlls/amxmodx_mm_i386.so" >> /opt/steam/hlds/cstrike/addons/metamod/plugins.ini && \
    rm -f amxmodx-1.10.0-git5474-base-linux.tar.gz amxmodx-1.10.0-git5474-cstrike-linux.tar.gz && \
    apt-get remove -y wget unzip && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Note: For GunGame support, add the GunGame plugin after building:
# RUN wget https://github.com/AMXX-Plugins/GunGame/raw/master/plugins/gungame.amxx -P /opt/steam/hlds/cstrike/addons/amxmodx/plugins/ && \
#     echo "gungame.amxx" >> /opt/steam/hlds/cstrike/addons/amxmodx/configs/plugins.ini
