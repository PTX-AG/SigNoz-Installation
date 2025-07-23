#!/bin/bash

set -e  # Exit on error

# Update system packages
sudo apt update
sudo apt upgrade -y

# Install dependencies for ClickHouse repo
sudo apt install -y apt-transport-https ca-certificates dirmngr gnupg curl

# Add ClickHouse GPG key and repository (updated for 2025)
sudo mkdir -p /usr/share/keyrings
curl -fsSL https://packages.clickhouse.com/rpm/lts/repodata/repomd.xml.key | sudo gpg --dearmor -o /usr/share/keyrings/clickhouse-keyring.gpg
ARCH=$(dpkg --print-architecture)
echo "deb [signed-by=/usr/share/keyrings/clickhouse-keyring.gpg arch=${ARCH}] https://packages.clickhouse.com/deb stable main" | sudo tee /etc/apt/sources.list.d/clickhouse.list
sudo apt update

# Install ClickHouse server and client (do not start yet)
sudo apt install -y clickhouse-server clickhouse-client

# Set password for ClickHouse default user (used in SigNoz DSN)
sudo mkdir -p /etc/clickhouse-server/users.d
sudo bash -c 'cat <<EOF > /etc/clickhouse-server/users.d/default-password.xml
<clickhouse>
    <users>
        <default>
            <password>password</password>
            <access_management>1</access_management>
        </default>
    </users>
</clickhouse>
EOF'
sudo chown -R clickhouse:clickhouse /etc/clickhouse-server/users.d

# Install Zookeeper
sudo apt install -y default-jdk
curl -L https://dlcdn.apache.org/zookeeper/zookeeper-3.8.4/apache-zookeeper-3.8.4-bin.tar.gz -o zookeeper.tar.gz
tar -xzf zookeeper.tar.gz
sudo mkdir -p /opt/zookeeper /var/lib/zookeeper /var/log/zookeeper
sudo cp -r apache-zookeeper-3.8.4-bin/* /opt/zookeeper
sudo bash -c 'cat <<EOF > /opt/zookeeper/conf/zoo.cfg
tickTime=2000
dataDir=/var/lib/zookeeper
clientPort=2181
admin.serverPort=3181
EOF'
sudo bash -c 'cat <<EOF > /opt/zookeeper/conf/zoo.env
ZOO_LOG_DIR=/var/log/zookeeper
EOF'
sudo useradd --system --home /opt/zookeeper --no-create-home --user-group --shell /sbin/nologin zookeeper || true
sudo chown -R zookeeper:zookeeper /opt/zookeeper /var/lib/zookeeper /var/log/zookeeper
sudo bash -c 'cat <<EOF > /etc/systemd/system/zookeeper.service
[Unit]
Description=Zookeeper
Documentation=http://zookeeper.apache.org

[Service]
EnvironmentFile=/opt/zookeeper/conf/zoo.env
Type=forking
WorkingDirectory=/opt/zookeeper
User=zookeeper
Group=zookeeper
ExecStart=/opt/zookeeper/bin/zkServer.sh start /opt/zookeeper/conf/zoo.cfg
ExecStop=/opt/zookeeper/bin/zkServer.sh stop /opt/zookeeper/conf/zoo.cfg
ExecReload=/opt/zookeeper/bin/zkServer.sh restart /opt/zookeeper/conf/zoo.cfg
TimeoutSec=30
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF'
sudo systemctl daemon-reload
sudo systemctl start zookeeper.service
sudo systemctl enable zookeeper.service

# Configure ClickHouse to use Zookeeper
sudo bash -c 'cat <<EOF > /etc/clickhouse-server/config.d/cluster.xml
<clickhouse replace="true">
    <distributed_ddl>
        <path>/clickhouse/task_queue/ddl</path>
    </distributed_ddl>
    <remote_servers>
        <cluster>
            <shard>
                <replica>
                    <host>127.0.0.1</host>
                    <port>9000</port>
                </replica>
            </shard>
        </cluster>
    </remote_servers>
    <zookeeper>
        <node>
            <host>127.0.0.1</host>
            <port>2181</port>
        </node>
    </zookeeper>
    <macros>
        <shard>01</shard>
        <replica>01</replica>
    </macros>
</clickhouse>
EOF'
sudo chown clickhouse:clickhouse /etc/clickhouse-server/config.d/cluster.xml

# Start ClickHouse
sudo systemctl start clickhouse-server.service
sudo systemctl enable clickhouse-server.service

# Run ClickHouse migrations for SigNoz
ARCH=$(uname -m | sed 's/x86_64/amd64/g' | sed 's/aarch64/arm64/g')
curl -L https://github.com/SigNoz/signoz-otel-collector/releases/latest/download/signoz-schema-migrator_linux_${ARCH}.tar.gz -o signoz-schema-migrator.tar.gz
tar -xzf signoz-schema-migrator.tar.gz
./signoz-schema-migrator_linux_${ARCH}/bin/signoz-schema-migrator sync --dsn="tcp://localhost:9000?password=password" --replication=true --up=
./signoz-schema-migrator_linux_${ARCH}/bin/signoz-schema-migrator async --dsn="tcp://localhost:9000?password=password" --replication=true --up=

# Install SigNoz
curl -L https://github.com/SigNoz/signoz/releases/latest/download/signoz_linux_${ARCH}.tar.gz -o signoz.tar.gz
tar -xzf signoz.tar.gz
sudo mkdir -p /opt/signoz /var/lib/signoz
sudo cp -r signoz_linux_${ARCH}/* /opt/signoz
sudo bash -c 'cat <<EOF > /opt/signoz/conf/systemd.env
SIGNOZ_INSTRUMENTATION_LOGS_LEVEL=info
INVITE_EMAIL_TEMPLATE=/opt/signoz/templates/invitation_email_template.html
SIGNOZ_SQLSTORE_SQLITE_PATH=/var/lib/signoz/signoz.db
SIGNOZ_WEB_ENABLED=true
SIGNOZ_WEB_DIRECTORY=/opt/signoz/web
SIGNOZ_JWT_SECRET=secret
SIGNOZ_ALERTMANAGER_PROVIDER=signoz
SIGNOZ_TELEMETRYSTORE_PROVIDER=clickhouse
SIGNOZ_TELEMETRYSTORE_CLICKHOUSE_DSN=tcp://localhost:9000?password=password
DOT_METRICS_ENABLED=true
EOF'
sudo useradd --system --home /opt/signoz --no-create-home --user-group --shell /sbin/nologin signoz || true
sudo chown -R signoz:signoz /var/lib/signoz /opt/signoz
sudo bash -c 'cat <<EOF > /etc/systemd/system/signoz.service
[Unit]
Description=SigNoz
Documentation=https://signoz.io/docs
After=clickhouse-server.service

[Service]
User=signoz
Group=signoz
Type=simple
KillMode=mixed
Restart=on-failure
WorkingDirectory=/opt/signoz
EnvironmentFile=/opt/signoz/conf/systemd.env
ExecStart=/opt/signoz/bin/signoz --config=/opt/signoz/conf/prometheus.yml --use-logs-new-schema=true --use-trace-new-schema=true

[Install]
WantedBy=multi-user.target
EOF'
sudo systemctl daemon-reload
sudo systemctl start signoz.service
sudo systemctl enable signoz.service

# Cleanup temporary files
rm -rf zookeeper.tar.gz apache-zookeeper-3.8.4-bin signoz-schema-migrator.tar.gz signoz-schema-migrator_linux_${ARCH} signoz.tar.gz signoz_linux_${ARCH}

# Verification instructions
echo "Installation completed successfully."
echo "Verify services:"
echo "  sudo systemctl status clickhouse-server.service"
echo "  sudo systemctl status zookeeper.service"
echo "  sudo systemctl status signoz.service"
echo "Access SigNoz UI at http://localhost:3301 (or your server IP:3301)."
echo "Default credentials: admin@signoz.io / SigNozPassword"
echo "Note: In production, change the ClickHouse password and SigNoz JWT secret."