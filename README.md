# PulseChainValidator

This is a simple script to get up and running with a PulseChain Validator.  It has been tested with Ubuntu 22.04 LTS on a clean install.  This script was built to make the entire process as seamless and automated as possible.  
<br>
Executing this script will install all dependencies required for Go-Pulse and Lighthouse-Pulse, and then it will clone and build all required projects (Go-Pulse, Lighthouse-Pulse, and the Deposit CLI tool).  The script will then prompt the user for some basic setup configuration such as the rewards wallet address, Go-Pulse port (30303 recommended), the Lighthouse port (9000 recommended), the public IP Address of the server, etc.  The script will also create all the required services so that the clients can auto start on system reboot. Finally, the script will open up the ports needed for Go-Pulse and Lighthouse-Pulse, and import the keys into the validator client.
<br>

After the script completes, Go-Pulse, Lighthouse-Beacon and Lighthouse-Validator will automatically start and begin the sync process.  Don't forget to open up and forward the required ports on your router!
<br>
<br>

INSTRUCTIONS:
<br>
<br>
cd ~
<br>
git clone https://github.com/Jerkistan/PulseChainValidator.git
<br>
cd PulseChainValidator
<br>
chmod +x setup.sh
<br>
./setup.sh
<br>


If you are feeling generous enough to thank me for my time, send me some PLS at <b>0x5eff71d47c9cc8e384f6e6fb72058e12fe1507a6</b> :)
