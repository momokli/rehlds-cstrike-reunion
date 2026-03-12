FROM ghcr.io/blsalin/rehlds-cstrike:latest

USER root

# Copy repository assets from build context
COPY docker-assets/maps/ /opt/steam/hlds/cstrike/maps/
COPY docker-assets/plugins/ /opt/steam/hlds/cstrike/addons/amxmodx/plugins/
COPY gg_213c_full.zip /tmp/gg_213c_full.zip

RUN apt-get update && \
    apt-get install -y wget unzip xz-utils && \
    wget https://github.com/rehlds/ReUnion/releases/download/0.2.0.25/reunion-0.2.0.25.zip && \
    unzip reunion-0.2.0.25.zip -d /tmp/reunion && \
    mkdir -p /opt/steam/hlds/cstrike/addons/reunion && \
    cp /tmp/reunion/bin/Linux/reunion_mm_i386.so /opt/steam/hlds/cstrike/addons/reunion/ && \
    cp /tmp/reunion/reunion.cfg /opt/steam/hlds/cstrike/ && \
    sed -i 's/^SteamIdHashSalt.*/SteamIdHashSalt = ThisIsMyRandomSalt123456789/' /opt/steam/hlds/cstrike/reunion.cfg && \
    echo "linux addons/amxmodx/dlls/amxmodx_mm_i386.so" > /opt/steam/hlds/cstrike/addons/metamod/plugins.ini && \
    rm -rf /tmp/reunion reunion-0.2.0.25.zip && \
    wget https://amxmodx.org/amxxdrop/1.10/amxmodx-1.10.0-git5474-base-linux.tar.gz && \
    tar -xzf amxmodx-1.10.0-git5474-base-linux.tar.gz -C /opt/steam/hlds/cstrike/ && \
    wget https://amxmodx.org/amxxdrop/1.10/amxmodx-1.10.0-git5474-cstrike-linux.tar.gz && \
    tar -xzf amxmodx-1.10.0-git5474-cstrike-linux.tar.gz -C /opt/steam/hlds/cstrike/ && \
    echo "linux addons/reunion/reunion_mm_i386.so" >> /opt/steam/hlds/cstrike/addons/metamod/plugins.ini && \
    rm -f amxmodx-1.10.0-git5474-base-linux.tar.gz amxmodx-1.10.0-git5474-cstrike-linux.tar.gz && \
    wget https://github.com/yapb/yapb/releases/download/4.4.957/yapb-4.4.957-linux.tar.xz && \
    tar -xf yapb-4.4.957-linux.tar.xz -C /tmp/ && \
    mkdir -p /opt/steam/hlds/cstrike/addons/yapb && \
    cp -r /tmp/addons/yapb/* /opt/steam/hlds/cstrike/addons/yapb/ && \
    cp /tmp/addons/yapb/yapb.cfg /opt/steam/hlds/cstrike/ 2>/dev/null || true && \
    rm -f yapb-4.4.957-linux.tar.xz && \
    rm -rf /tmp/addons && \
    wget https://github.com/rehlds/ReAPI/releases/download/5.26.0.338/reapi-bin-5.26.0.338.zip -O /tmp/reapi.zip && \
    unzip /tmp/reapi.zip -d /tmp/reapi && \
    mkdir -p /opt/steam/hlds/cstrike/addons/amxmodx/modules && \
    cp /tmp/reapi/addons/amxmodx/modules/reapi_amxx_i386.so /opt/steam/hlds/cstrike/addons/amxmodx/modules/ && \
    echo "reapi_amxx_i386.so" >> /opt/steam/hlds/cstrike/addons/amxmodx/configs/modules.ini && \
    echo "fakemeta" >> /opt/steam/hlds/cstrike/addons/amxmodx/configs/modules.ini && \
    echo "hamsandwich" >> /opt/steam/hlds/cstrike/addons/amxmodx/configs/modules.ini && \
    rm -rf /tmp/reapi /tmp/reapi.zip && \
    wget https://github.com/ReDeathmatch/ReDeathmatch_AMXX/releases/download/1.0.0-b11/ReDeathmatch-1.0.0-b11.zip -O /tmp/redm.zip && \
    unzip /tmp/redm.zip -d /tmp/redm && \
    cp -r /tmp/redm/cstrike/addons/amxmodx/* /opt/steam/hlds/cstrike/addons/amxmodx/ && \
    echo "ReDeathmatch.amxx" >> /opt/steam/hlds/cstrike/addons/amxmodx/configs/plugins.ini && \
    echo "redm_spawns.amxx" >> /opt/steam/hlds/cstrike/addons/amxmodx/configs/plugins.ini && \
    rm -rf /tmp/redm /tmp/redm.zip && \
    mkdir -p /opt/steam/hlds/cstrike/maps && \
    # Install GunGame from local zip file if it exists
    if [ -f /tmp/gg_213c_full.zip ]; then \
        echo "Installing GunGame from local zip file..." && \
        unzip -q /tmp/gg_213c_full.zip -d /tmp/ && \
        cp -r /tmp/gg_213c_full/addons/amxmodx/* /opt/steam/hlds/cstrike/addons/amxmodx/ && \
        if [ -d /tmp/gg_213c_full/sound ]; then cp -r /tmp/gg_213c_full/sound/* /opt/steam/hlds/cstrike/sound/ 2>/dev/null || true; fi && \
        echo "gungame.amxx" >> /opt/steam/hlds/cstrike/addons/amxmodx/configs/plugins.ini && \
        rm -rf /tmp/gg_213c_full /tmp/gg_213c_full.zip; \
    else \
        echo "GunGame zip file not found, skipping installation."; \
    fi && \
    apt-get remove -y wget unzip xz-utils && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
