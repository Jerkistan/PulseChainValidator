#GETH_REPO="https://gitlab.com/pulsechaincom/go-pulse.git"
#LIGHTHOUSE_REPO="https://gitlab.com/pulsechaincom/lighthouse-pulse.git"

# update, upgrade
sudo apt-get update -y
sudo apt-get upgrade -y

cd ~
cd /lighthouse-pulse
git pull

cd ~
cd /go-pulse
git pull


# build geth
cd ~
git clone $GETH_REPO
cd go-pulse
make
cd ~


# build lighthouse
cd ~
cd lighthouse-pulse
source /home/$USER/.cargo/env && make
cd ~

systemctl stop geth lighthouse-beacon lighthouse-validator

mv /home/$USER/validator/geth /home/$USER/validator/geth.backup
mv /home/$USER/validator/lighthouse /home/$USER/validator/lighthouse.backup

mv build/bin/geth /home/$USER/validator
mv .cargo/bin/lighthouse /home/$USER/validator

systemctl start geth lighthouse-beacon lighthouse-validator

echo "Update Complete.  Rebooting the machine is recommended"
