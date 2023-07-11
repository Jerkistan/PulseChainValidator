# general config
GETH_CHAIN="pulsechain"
LIGHTHOUSE_CHAIN="pulsechain"

GETH_REPO="https://gitlab.com/pulsechaincom/go-pulse.git"
LIGHTHOUSE_REPO="https://gitlab.com/pulsechaincom/lighthouse-pulse.git"
STAKING_DEPOSIT_CLI_REPO=""https://gitlab.com/pulsechaincom/staking-deposit-cli.git
LIGHTHOUSE_CHECKPOINT_URL="https://checkpoint.pulsechain.com"


#####################################################################   



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
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y


# make the directories where the clients / data will live
cd ~
mkdir validator
cd /validator
mkdir data
cd /data
mkdir geth
mkdir beacon


# generate execution and consensus client secret
cd ~
mkdir -p /home/$USER/validator/jwt
openssl rand -hex 32 | tee /home/$USER/validator/jwt/secret > /dev/null



# get the staking deposit cli app and build it.
cd ~
git clone $STAKING_DEPOSIT_CLI_REPO
cd /home/$USER/staking-deposit-cli && pip3 install -r requirements.txt && sudo python3 setup.py install


# get geth and build it
cd ~
git clone $GETH_REPO
cd go-pulse
make
mv build/bin/geth /home/$USER/validator 


# get lighthouse and build it
cd ~
git clone $LIGHTHOUSE_REPO
cd lighthouse-pulse
source /home/$USER/.cargo/env && make
cd ~
mv .cargo/bin/lighthouse /home/$USER/validator


# prompt for variables that will be used to configure geth/lighthouse
read -p "Enter the rewards address: " FEE_RECIPIENT
read -p "Enter the public IP address: " SERVER_IP_ADDRESS
read -p "Enter the Geth port number: " GETH_PORT
read -p "Enter the Lighthouse port number: " LIGHTHOUSE_PORT


# generate key/keystore files
cd /home/$USER/staking-deposit-cli && ./deposit.sh --language=English new-mnemonic --num_validators=1 --mnemonic_language=English --chain=pulsechain --eth1_withdrawal_address=$FEE_RECIPIENT
mv /home/$USER/staking-deposit-cli/validator_keys /home/$USER/validator

# build the geth service so it can auto run on reboot
sudo tee /etc/systemd/system/geth.service > /dev/null <<EOT
[Unit]
Description=Geth (Go-Pulse)
After=network.target
Wants=network.target

[Service]
User=$USER
Group=$USER
Type=simple
Restart=always
RestartSec=5
ExecStart=/home/$USER/validator/geth \
--pulsechain \
--datadir=/home/$USER/validator/data/geth \
--port=$GETH_PORT \
--discovery.port=$GETH_PORT \
--http \
--http.api=engine,eth,net,admin,debug \
--authrpc.jwtsecret=/home/$USER/validator/jwt/secret\


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
User=$USER
Group=$USER
Type=simple
Restart=always
RestartSec=5
ExecStart=/home/$USER/validator/lighthouse bn \
--network pulsechain \
--datadir=/home/$USER/validator/data/beacon \
--execution-endpoint=http://localhost:8551 \
--execution-jwt=/home/$USER/validator/jwt/secret \
--port=$LIGHTHOUSE_PORT \
--enr-address=$SERVER_IP_ADDRESS \
--enr-tcp-port=$LIGHTHOUSE_PORT \
--enr-udp-port=$LIGHTHOUSE_PORT \
--suggested-fee-recipient=$FEE_RECIPIENT \
--checkpoint-sync-url=$LIGHTHOUSE_CHECKPOINT_URL
--http\

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
User=$USER
Group=$USER
Type=simple
Restart=always
RestartSec=5
ExecStart=/home/$USER/validator/lighthouse vc \
--network pulsechain \
--suggested-fee-recipient=$FEE_RECIPIENT\

[Install]
WantedBy=multi-user.target
EOT


cd ~
cd validator
./lighthouse account validator import --directory /home/$USER/validator/validator_keys --network=pulsechain


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
