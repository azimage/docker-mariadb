# (c) Wong Hoi Sing Edison <hswong3i@pantarei-design.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

FROM mariadb:10.0

ENV POD_NAMESPACE "default"

ENTRYPOINT [ "dumb-init", "--" ]
CMD        [ "sh", "-c", "docker-entrypoint.sh mysqld && gosu mysql mysqld $@" ]

# Prepare APT depedencies
RUN set -ex \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y curl patch \
    && rm -rf /var/lib/apt/lists/*

# Install MariaDB Galera Cluster
RUN set -ex \
    && { \
        echo "mariadb-galera-server-$MARIADB_MAJOR" mysql-server/root_password password 'unused'; \
        echo "mariadb-galera-server-$MARIADB_MAJOR" mysql-server/root_password_again password 'unused'; \
    } | debconf-set-selections \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y mariadb-galera-server-$MARIADB_MAJOR \
    && rm -rf /var/lib/apt/lists/* \
    && sed -ri 's/^user\s/#&/' /etc/mysql/my.cnf /etc/mysql/conf.d/* \
    && rm -rf /var/lib/mysql/* \
    && mkdir -p /var/lib/mysql /var/run/mysqld \
    && chown -R mysql:mysql /var/lib/mysql /var/run/mysqld \
    && chmod 777 /var/run/mysqld \
    && find /etc/mysql/ -name '*.cnf' -print0 \
        | xargs -0 grep -lZE '^(bind-address|log)' \
        | xargs -rt -0 sed -Ei 's/^(bind-address|log)/#&/' \
    && echo '[mysqld]\nskip-host-cache\nskip-name-resolve' > /etc/mysql/conf.d/docker.cnf

# Install dumb-init
RUN set -ex \
    && curl -skL https://github.com/Yelp/dumb-init/releases/download/v1.2.1/dumb-init_1.2.1_amd64 > /usr/local/bin/dumb-init \
    && chmod 0755 /usr/local/bin/dumb-init

# Install peer-finder
RUN set -ex \
    && curl -skL https://storage.googleapis.com/kubernetes-release/pets/peer-finder > /usr/local/bin/peer-finder \
    && chmod 0755 /usr/local/bin/peer-finder

# Copy files
COPY files /

# Apply patches
RUN set -ex \
    && patch -d/ -p1 < /.patch
