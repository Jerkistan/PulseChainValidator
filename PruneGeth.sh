GETH="/home/$USER/validator/geth"
GETH_DATA="/home/$USER/validator/data/geth"

# stop geth
sudo systemctl stop geth

# run prune command
sudo $GETH --datadir $GETH_DATA snapshot prune-state

# start geth
sudo systemctl start geth


echo "The prune process is now complete.  Rebooting the machine is recommended."
