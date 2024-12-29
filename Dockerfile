FROM ubuntu:focal

# Install package requirements
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y software-properties-common build-essential base-files sudo curl wget unzip tar python3 python3-pip python3-gssapi pkg-config libzstd-dev libreadline-dev libkrb5-dev libapr1-dev libevent-dev bzip2 bison openssl libxml2-dev libyaml-dev libcurl4-openssl-dev libbz2-dev libxerces-c-dev libperl-dev flex gcc g++ iproute2 less iputils-ping rsync lsof ssh sshpass locales nano vim

# Install Greenplum DB
WORKDIR /usr/local/app
COPY ./gpdb-archive-main.zip /usr/local/app
RUN unzip gpdb-archive-main.zip
WORKDIR /usr/local/app/gpdb-archive-main
RUN ./configure --with-perl --with-python --with-libxml --with-gssapi --prefix=/usr/local/gpdb
RUN make -j8
RUN make -j8 install
RUN PATH=/usr/local/gpdb/bin:$PATH pip install psycopg2 psutil

# Configure gpadmin
RUN groupadd gpadmin
RUN useradd -m -d /home/gpadmin -g gpadmin gpadmin
RUN usermod -aG sudo gpadmin
RUN echo 'gpadmin:gpadmin' | chpasswd
RUN mkdir -p /data/coordinator
RUN mkdir -p /home/gpadmin/gpconfigs
RUN cp -r /usr/local/gpdb/docs/cli_help/gpconfigs /home/gpadmin/
RUN echo 'source /usr/local/gpdb/greenplum_path.sh' >> /home/gpadmin/.bashrc
RUN chown -R gpadmin:gpadmin /home/gpadmin /data

# Configure startup settings
RUN printf '%s\n' '#/bin/bash' > /root/.startup.sh
RUN chmod u+x /root/.startup.sh
RUN echo "gpadmin ALL=(root) NOPASSWD: /root/.startup.sh" >> /etc/sudoers
RUN printf '%s\n' 'sudo -u root /root/.startup.sh' >> /home/gpadmin/.bashrc

# Enable mutable hostfile in the container
RUN touch /home/gpadmin/.hosts && chown -R gpadmin:gpadmin /home/gpadmin/.hosts
RUN for file in `find / -type f -name libnss_files* 2>/dev/null`; do cp "$file" "${file}.bak" && sed -ie 's:/etc/hosts:/var/hosts:g' "$file" ; done
RUN printf '%s\n' '/bin/cp /etc/hosts /var/hosts' '/bin/cat /home/gpadmin/.hosts >> /var/hosts' >> /root/.startup.sh

# Configure SSH settings
USER gpadmin
RUN ssh-keygen -q -t rsa -N '' -f /home/gpadmin/.ssh/id_rsa
USER root
RUN printf '%s\n' 'service ssh start >/dev/null' >> /root/.startup.sh

# Configure locales
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# Add shell script tools
USER gpadmin
RUN printf '%s\n' '#!/bin/bash' \
           "for hostname_list in \`cat /home/gpadmin/.hosts | sed -re 's,\\s+, ,g' | cut -d ' ' -f 2-\`; do" \
           '  for hostname in ${hostname_list}; do' \
           '    SSHPASS="gpadmin" sshpass -e ssh-copy-id -o StrictHostKeyChecking=no $hostname' \
           '  done' \
           'done' \
    > /home/gpadmin/auto_hosts_configure.sh && chmod a+x /home/gpadmin/auto_hosts_configure.sh
USER root

# User and work directory settings
EXPOSE 22 5432 6000-8000
WORKDIR /home/gpadmin
USER gpadmin
CMD ["/bin/bash"]
