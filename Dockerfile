# daemon runs in the background
# run something like tail /var/log/athena/current to see the status
# be sure to run with volumes, ie:
# docker run -v $(pwd)/athena:/var/lib/athena -v $(pwd)/wallet:/home/athena --rm -ti athena:0.2.2
ARG base_image_version=0.10.0
FROM phusion/baseimage:$base_image_version

ADD https://github.com/just-containers/s6-overlay/releases/download/v1.21.2.2/s6-overlay-amd64.tar.gz /tmp/
RUN tar xzf /tmp/s6-overlay-amd64.tar.gz -C /

ADD https://github.com/just-containers/socklog-overlay/releases/download/v2.1.0-0/socklog-overlay-amd64.tar.gz /tmp/
RUN tar xzf /tmp/socklog-overlay-amd64.tar.gz -C /

ARG ATHENA_BRANCH=master
ENV ATHENA_BRANCH=${ATHENA_BRANCH}

# install build dependencies
# checkout the latest tag
# build and install
RUN apt-get update && \
    apt-get install -y \
      build-essential \
      python-dev \
      gcc-4.9 \
      g++-4.9 \
      git cmake \
      libboost1.58-all-dev \
      librocksdb-dev && \
    git clone https://github.com/athena-network/athena.git /src/athena && \
    cd /src/athena && \
    git checkout $ATHENA_BRANCH && \
    mkdir build && \
    cd build && \
    cmake -DCMAKE_CXX_FLAGS="-g0 -Os -fPIC -std=gnu++11" .. && \
    make -j$(nproc) && \
    mkdir -p /usr/local/bin && \
    cp src/Athena /usr/local/bin/Athena && \
    cp src/services /usr/local/bin/services && \
    cp src/wallet /usr/local/bin/wallet && \
    cp src/solominer /usr/local/bin/solominer && \
    strip /usr/local/bin/Athena && \
    strip /usr/local/bin/services && \
    strip /usr/local/bin/wallet && \
    strip /usr/local/bin/solominer && \
    cd / && \
    rm -rf /src/athena && \
    apt-get remove -y build-essential python-dev gcc-4.9 g++-4.9 git cmake libboost1.58-all-dev librocksdb-dev && \
    apt-get autoremove -y && \
    apt-get install -y  \
      libboost-system1.58.0 \
      libboost-filesystem1.58.0 \
      libboost-thread1.58.0 \
      libboost-date-time1.58.0 \
      libboost-chrono1.58.0 \
      libboost-regex1.58.0 \
      libboost-serialization1.58.0 \
      libboost-program-options1.58.0 \
      libicu55

# setup the athena service
RUN useradd -r -s /usr/sbin/nologin -m -d /var/lib/athena athena && \
    useradd -s /bin/bash -m -d /home/athena athena && \
    mkdir -p /etc/services.d/athena/log && \
    mkdir -p /var/log/athena && \
    echo "#!/usr/bin/execlineb" > /etc/services.d/athena/run && \
    echo "fdmove -c 2 1" >> /etc/services.d/athena/run && \
    echo "cd /var/lib/athena" >> /etc/services.d/athena/run && \
    echo "export HOME /var/lib/athena" >> /etc/services.d/athena/run && \
    echo "s6-setuidgid athena /usr/local/bin/Athena" >> /etc/services.d/athena/run && \
    chmod +x /etc/services.d/athena/run && \
    chown nobody:nogroup /var/log/athena && \
    echo "#!/usr/bin/execlineb" > /etc/services.d/athena/log/run && \
    echo "s6-setuidgid nobody" >> /etc/services.d/athena/log/run && \
    echo "s6-log -bp -- n20 s1000000 /var/log/athena" >> /etc/services.d/athena/log/run && \
    chmod +x /etc/services.d/athena/log/run && \
    echo "/var/lib/athena true athena 0644 0755" > /etc/fix-attrs.d/athena-home && \
    echo "/home/athena true athena 0644 0755" > /etc/fix-attrs.d/athena-home && \
    echo "/var/log/athena true nobody 0644 0755" > /etc/fix-attrs.d/athena-logs

VOLUME ["/var/lib/athena", "/home/athena","/var/log/athena"]

ENTRYPOINT ["/init"]
CMD ["/usr/bin/execlineb", "-P", "-c", "emptyenv cd /home/athena export HOME /home/athena s6-setuidgid athena /bin/bash"]
