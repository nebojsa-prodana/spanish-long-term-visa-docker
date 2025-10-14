FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    DISPLAY=:0

# --- Essential packages first ---
# Split into separate RUN commands for better layer caching
# If one package fails (rate limits, network issues, archive availability), 
# we don't lose progress on the others and can retry from the failed layer
RUN apt-get update
RUN apt-get install -y wget curl unzip ca-certificates
RUN apt-get install -y xvfb x11vnc 
RUN apt-get install -y python3-websockify
RUN apt-get install -y fonts-dejavu-core
RUN apt-get install -y sudo
RUN apt-get install -y xclip

# --- Locale setup ---
RUN apt-get install -y locales && \
    locale-gen en_US.UTF-8 && \
    update-locale LANG=en_US.UTF-8

# --- Minimal window manager instead of full desktop ---
# Using openbox instead of lxde-core for minimal GUI support
RUN apt-get install -y openbox
RUN apt-get install -y dbus-x11

# --- Basic GUI libraries for Firefox ---
RUN apt-get install -y libxrender1 libxtst6 libgtk-3-0
RUN apt-get install -y libdbus-glib-1-2 libxt6 libasound2

# --- Certificate tools ---
RUN apt-get install -y libnss3-tools p11-kit

# --- Certificate tools ---
RUN apt-get install -y libnss3-tools p11-kit

# --- Cleanup ---
RUN apt-get clean && rm -rf /var/lib/apt/lists/*

# --- Install noVNC ---
RUN wget -q https://github.com/novnc/noVNC/archive/v1.3.0.tar.gz && \
    tar -xzf v1.3.0.tar.gz && \
    mv noVNC-1.3.0 /usr/share/novnc && \
    rm v1.3.0.tar.gz

# --- Install default OpenJDK (Ubuntu 20.04 comes with OpenJDK 11) ---
# OpenJDK 11 can run Java 7 applets and has good compatibility
RUN apt-get update && apt-get install -y default-jdk && \
    mkdir -p /usr/lib/mozilla/plugins && \
    find /usr/lib/jvm -name "libnpjp2.so" -exec ln -sf {} /usr/lib/mozilla/plugins/ \;

# --- Set Java environment ---
ENV JAVA_HOME=/usr/lib/jvm/default-java
ENV PATH=$JAVA_HOME/bin:$PATH

# --- Firefox ESR 52 (last NPAPI-compatible) ---
RUN wget -q https://ftp.mozilla.org/pub/firefox/releases/52.9.0esr/linux-x86_64/en-US/firefox-52.9.0esr.tar.bz2 && \
    tar -xjf firefox-52.9.0esr.tar.bz2 -C /opt && \
    ln -sf /opt/firefox/firefox /usr/bin/firefox && \
    ln -sf /opt/firefox/firefox /usr/bin/x-www-browser && \
    rm firefox-52.9.0esr.tar.bz2

# --- AutoFirma 1.9 ---
RUN wget -q https://firmaelectronica.gob.es/content/dam/firmaelectronica/descargas-software/autofirma19/Autofirma_Linux_Debian.zip -O /tmp/autofirma.zip && \
    unzip /tmp/autofirma.zip -d /tmp/autofirma && \
    apt-get install -y /tmp/autofirma/*.deb || apt-get -f install -y && \
    rm -rf /tmp/autofirma.zip /tmp/autofirma

# --- User setup ---
RUN useradd -ms /bin/bash autofirma && \
    echo "autofirma ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
USER autofirma
WORKDIR /home/autofirma

# --- Volume for certificates ---
ENV CERT_DIR=/certs
VOLUME ["/certs"]

# --- Firefox profile setup ---
RUN mkdir -p /home/autofirma/.mozilla/firefox && \
    echo '[Profile0]\nName=default\nIsRelative=1\nPath=profile.default\nDefault=1' > /home/autofirma/.mozilla/firefox/profiles.ini && \
    mkdir -p /home/autofirma/.mozilla/firefox/profile.default && \
    chmod -R 700 /home/autofirma/.mozilla && chown -R autofirma:autofirma /home/autofirma/.mozilla

# --- Start script ---
COPY start.sh /usr/local/bin/start.sh
COPY troubleshoot.sh /usr/local/bin/troubleshoot.sh
COPY smoketest.sh /usr/local/bin/smoketest.sh
COPY configure-firefox.sh /usr/local/bin/configure-firefox.sh
USER root
RUN chmod +x /usr/local/bin/start.sh && chmod +x /usr/local/bin/troubleshoot.sh && chmod +x /usr/local/bin/smoketest.sh && chmod +x /usr/local/bin/configure-firefox.sh
USER autofirma

EXPOSE 8080
CMD ["/usr/local/bin/start.sh"]
