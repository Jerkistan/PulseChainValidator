# general config
PLS_USER="pls"
JWT_SECRET_DIR="/var/lib/jwt"

# chain flags
GETH_CHAIN="pulsechain"
LIGHTHOUSE_CHAIN="pulsechain"

# geth config
GETH_DIR="/opt/geth"
GETH_DATA="/opt/geth/data"
GETH_REPO="https://gitlab.com/pulsechaincom/go-pulse.git"
GETH_REPO_NAME="go-pulse"

# lighthouse config
LIGHTHOUSE_DIR="/opt/lighthouse"
LIGHTHOUSE_BEACON_DATA="/opt/lighthouse/data/beacon"
LIGHTHOUSE_REPO="https://gitlab.com/pulsechaincom/lighthouse-pulse.git"
LIGHTHOUSE_REPO_NAME="lighthouse-pulse"
LIGHTHOUSE_CHECKPOINT_URL="https://checkpoint.pulsechain.com"


#####################################################################   


# create a user for running the validator
sudo useradd -m -s /bin/false -d /home/$PLS_USER $PLS_USER


# generate execution and consensus client secret
sudo mkdir -p $JWT_SECRET_DIR
openssl rand -hex 32 | sudo tee $JWT_SECRET_DIR/secret > /dev/null
sudo chown -R $PLS_USER:$PLS_USER $JWT_SECRET_DIR
sudo chmod 400 $JWT_SECRET_DIR/secret



# update, upgrade, and get required packages
sudo apt-get update -y
sudo apt-get upgrade -y
sudo apt install -y python3-pip
sudo apt-get install -y build-essential
sudo apt-get install -y cmake
sudo apt-get install -y clang
sudo apt-get install -y wget
sudo apt-get install -y jq
sudo apt-get install -y openssh-server
sudo apt-get install -y protobuf-compiler
sudo snap install --classic go
sudo -u $PLS_USER bash -c "cd \$HOME && curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y"
sudo -u $PLS_USER bash -c "exit"


# get the staking deposit cli app and build it.
cd ~
git clone https://gitlab.com/pulsechaincom/staking-deposit-cli.git
cd /home/$USER/staking-deposit-cli && pip3 install -r requirements.txt && sudo python3 setup.py install


# get geth and build it
git clone $GETH_REPO
sleep 0.5
sudo mkdir -p $GETH_DIR
sudo mv $GETH_REPO_NAME/* $GETH_DIR
rm -rf $GETH_REPO_NAME
sudo chown -R $PLS_USER:$PLS_USER $GETH_DIR
cd $GETH_DIR
sudo -u $PLS_USER make
export PATH=$PATH:$GETH_DIR/build/bin
sudo -u $PLS_USER mkdir -p $GETH_DATA
sudo chown -R $PLS_USER:$PLS_USER $GETH_DIR


# get lighthouse and build it
cd ~
git clone $LIGHTHOUSE_REPO
sleep 0.5 # ugh, wait
sudo mkdir -p $LIGHTHOUSE_DIR
sudo mv $LIGHTHOUSE_REPO_NAME/* $LIGHTHOUSE_DIR
rm -rf $LIGHTHOUSE_REPO_NAME
sudo chown -R $PLS_USER:$PLS_USER $LIGHTHOUSE_DIR
cd $LIGHTHOUSE_DIR
sudo -u $PLS_USER bash -c "source \$HOME/.cargo/env && make"
sudo chown -R $PLS_USER:$PLS_USER $LIGHTHOUSE_DIR
sudo -u $PLS_USER ln -s /home/$PLS_USER/.cargo/bin/lighthouse /opt/lighthouse/lighthouse/lh
sudo -u $PLS_USER bash -c "exit"


# prompt for variables that will be used to configure geth/lighthouse
read -p "Enter the rewards address: " FEE_RECIPIENT
read -p "Enter the public IP address: " SERVER_IP_ADDRESS
read -p "Enter the Geth port number: " GETH_PORT
read -p "Enter the Lighthouse port number: " LIGHTHOUSE_PORT


# generate key/keystore files
cd /home/$USER/staking-deposit-cli && ./deposit.sh --language=English new-mnemonic --num_validators=1 --mnemonic_language=English --chain=pulsechain --eth1_withdrawal_address=$FEE_RECIPIENT


# build the geth service so it can auto run on reboot
sudo tee /etc/systemd/system/geth.service > /dev/null <<EOT
[Unit]
Description=Geth (Go-Pulse)
After=network.target
Wants=network.target

[Service]
User=$PLS_USER
Group=$PLS_USER
Type=simple
Restart=always
RestartSec=5
ExecStart=$GETH_DIR/build/bin/geth \
--$GETH_CHAIN \
--datadir=$GETH_DATA \
--port=$GETH_PORT \
--discovery.port=$GETH_PORT \
--http \
--http.api=engine,eth,net,admin,debug \
--authrpc.jwtsecret=$JWT_SECRET_DIR/secret\


[Install]
WantedBy=default.target
EOT


# build out the lighthouse beacon service so that lighthouse beacon can be restarted on boot
sudo tee /etc/systemd/system/lighthouse-beacon.service > /dev/null <<EOT
[Unit]
Description=Lighthouse Beacon
After=network.target
Wants=network.target

[Service]
User=$PLS_USER
Group=$PLS_USER
Type=simple
Restart=always
RestartSec=5
ExecStart=$LIGHTHOUSE_DIR/lighthouse/lh bn \
--network $LIGHTHOUSE_CHAIN \
--datadir=$LIGHTHOUSE_BEACON_DATA \
--execution-endpoint=http://localhost:8551 \
--execution-jwt=$JWT_SECRET_DIR/secret \
--port=$LIGHTHOUSE_PORT \
--enr-address=$SERVER_IP_ADDRESS \
--enr-tcp-port=$LIGHTHOUSE_PORT \
--enr-udp-port=$LIGHTHOUSE_PORT \
--suggested-fee-recipient=$FEE_RECIPIENT \
--checkpoint-sync-url=$LIGHTHOUSE_CHECKPOINT_URL \
--http

[Install]
WantedBy=multi-user.target
EOT


# build out the lighthouse validator service so that lighthouse validator can be restarted on boot
sudo tee /etc/systemd/system/lighthouse-validator.service > /dev/null <<EOT
[Unit]
Description=Lighthouse Validator
After=network.target
Wants=network.target

[Service]
User=$PLS_USER
Group=$PLS_USER
Type=simple
Restart=always
RestartSec=5
ExecStart=$LIGHTHOUSE_DIR/lighthouse/lh vc \
--network $LIGHTHOUSE_CHAIN \
--suggested-fee-recipient=$FEE_RECIPIENT

[Install]
WantedBy=multi-user.target
EOT


# copy keys to pls user directory and import into lighthouse then do some cleanup.
sudo cp -R /home/$USER/staking-deposit-cli/validator_keys /home/$PLS_USER
sudo chown -R $PLS_USER:$PLS_USER /home/$PLS_USER/validator_keys
sudo -u $PLS_USER bash -c "cd ~/ && cd /home/ && cd /opt/ && cd lighthouse && cd lighthouse && ./lh account validator import --directory /home/$PLS_USER/validator_keys --network=pulsechain"
sudo -u $PLS_USER bash -c "exit" 
sudo rm -R /home/$USER/staking-deposit-cli


# firewall rules to allow go-pulse and lighthouse services.  these ports should also be enabled and forwarded on your router
sudo ufw allow $LIGHTHOUSE_PORT/tcp
sudo ufw allow $LIGHTHOUSE_PORT/udp
sudo ufw allow $GETH_PORT/tcp
sudo ufw allow $GETH_PORT/udp
sudo ufw allow 22/tcp
sudo ufw --force enable


# start the services geth, beacon, and validator
sudo systemctl daemon-reload
sudo systemctl enable geth lighthouse-beacon lighthouse-validator
sudo systemctl start geth lighthouse-beacon lighthouse-validator
