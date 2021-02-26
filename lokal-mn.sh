#!/bin/bash
set -e
export LC_ALL="en_US.UTF-8"
binary_url=$2
file_name=$1
extension=".tar.gz"
#Are the the needed paramters provided?
if [ "$binary_url" = "" ] || [ "$file_name" = "" ]; then
	echo ""
	echo "In order to run this script, you need to add two parameters: first one is the full file name of the wallet on the Lokal Coin Github, the second one is the full binary url leading to the file on the Github."
	echo ""
	exit
fi
#Is the daemon already running?
is_lokal_running=`ps ax | grep -v grep | grep lokal_coind | wc -l`
if [ $is_lokal_running -eq 1 ]; then
	echo ""
	echo "A LokalCoin daemon is already running - this script is not to be used for upgrading!"
	echo ""
	exit
fi
echo ""
echo "#################################################"
echo "#   Welcome to the LokalCoin Masternode Setup   #"
echo "#################################################"
echo ""
echo "Running this script as root on Ubuntu 18.04 LTS or newer is highly recommended."
echo "Please note that this script will try to configure 6 GB of swap - the combined value of memory and swap should be at least 7 GB. Use the command 'free -h' to check the values (under 'Total')." 
echo ""
sleep 10
#ipaddr="$(dig +short myip.opendns.com @resolver1.opendns.com)"
ipaddr="$(wget -qO- ifconfig.me)"
while [[ $ipaddr = '' ]] || [[ $ipaddr = ' ' ]]; do
	read -p 'Unable to find an external IP, please provide one: ' ipaddr
	sleep 2
done
read -p 'Please provide masternodeblsprivkey: ' mnkey
while [[ $mnkey = '' ]] || [[ $mnkey = ' ' ]]; do
	read -p 'You did not provide a masternodeblsprivkey, please provide one: ' mnkey
	sleep 2
done
echo ""
echo "###############################################################"
echo "#  Installing dependencies / Updating the operating system    #"
echo "###############################################################"
echo ""
sleep 2
sudo apt-get -y update
sudo apt-get -y upgrade
sudo apt-get -y install ufw pwgen
echo ""
echo "###############################"
echo "#   Setting up the firewall   #"
echo "###############################"
echo ""
sleep 2
sudo ufw status
sudo ufw disable
sudo ufw allow ssh/tcp
sudo ufw limit ssh/tcp
sudo ufw allow 2513/tcp
sudo ufw logging on
sudo ufw --force enable
sudo ufw status
sudo iptables -A INPUT -p tcp --dport 2513 -j ACCEPT
echo ""
echo "Proceed with the setup of the swap file [y/n]?"
echo "(Defaults to 'y' in 5 seconds)"
set +e
read -t 5 cont
set -e
if [ "$cont" = "" ]; then
        cont=Y
fi
if [ $cont = 'y' ] || [ $cont = 'yes' ] || [ $cont = 'Y' ] || [ $cont = 'Yes' ]; then
		echo ""
		echo "###########################"
		echo "#   Setting up swapfile   #"
		echo "###########################"
		echo ""
		sudo swapoff -a
		sudo fallocate -l 6G /swapfile
		sudo chmod 600 /swapfile
		sudo mkswap /swapfile
		sudo swapon /swapfile
		echo "/swapfile swap swap defaults 0 0" >> /etc/fstab
		sleep 2
    else
        echo ""
		echo "Warning: Swap was not setup as desired. Use free -h command to check how much memory / swap is available."
		sleep 5
fi
echo ""
echo "###############################"
echo "#      Get/Setup binaries     #"
echo "###############################"
echo ""
sleep 3
cd ~
set +e
wget $binary_url
set -e
if test -e "$file_name$extension"; then
echo "Unpacking LokalCoin distribution"
systemctl stop lokal.service || true
	tar -xzvf $file_name$extension
	rm -r $file_name$extension
	mkdir LokalCoin
	mv lokal_coind ~/LokalCoin
	mv lokal_coin-cli ~/LokalCoin
	cd LokalCoin
	chmod +x lokal_coind
	chmod +x lokal_coin-cli
	echo "Binaries were saved to: /root/LokalCoin"
	echo ""
else
	echo ""
	echo "There was a problem downloading the binaries, please try running the script again."
	echo "Most likely are the parameters used to run the script wrong."
	echo ""
	exit -1
fi
echo "#################################"
echo "#     Configuring the wallet    #"
echo "#################################"
echo ""
echo "A .lokalcoin folder will be created, unless it already exists."
sleep 3
if [ -d ~/.lokalcoin ]; then
	if [ -e ~/.lokalcoin/lokalcoin.conf ]; then
	read -p "The file lokalcoin.conf already exists and will be replaced. Do you agree [y/n]?" cont
		if [ $cont = 'y' ] || [ $cont = 'yes' ] || [ $cont = 'Y' ] || [ $cont = 'Yes' ]; then
			sudo rm ~/.lokalcoin/lokalcoin.conf
			touch ~/.lokalcoin/lokalcoin.conf
			cd ~/.lokalcoin
		fi
	fi
else
	echo "Creating .lokalcoin dir"
	mkdir -p ~/.lokalcoin
	cd ~/.lokalcoin
	touch lokalcoin.conf
fi


echo "Configuring the lokalcoin.conf"
echo "#----" > lokalcoin.conf
echo "rpcuser=$(pwgen -s 16 1)" >> lokalcoin.conf
echo "rpcpassword=$(pwgen -s 64 1)" >> lokalcoin.conf
echo "rpcallowip=127.0.0.1" >> lokalcoin.conf
echo "rpcport=2512" >> lokalcoin.conf
echo "#----" >> lokalcoin.conf
echo "listen=1" >> lokalcoin.conf
echo "server=1" >> lokalcoin.conf
echo "daemon=1" >> lokalcoin.conf
echo "maxconnections=64" >> lokalcoin.conf
echo "#----" >> lokalcoin.conf
#echo "masternode=1" >> lokalcoin.conf
echo "masternodeblsprivkey=$mnkey" >> lokalcoin.conf
echo "externalip=$ipaddr" >> lokalcoin.conf
echo "#----" >> lokalcoin.conf
echo ""
echo "#######################################"
echo "#      Creating systemctl service     #"
echo "#######################################"
echo ""
cat <<EOF > /etc/systemd/system/lokal.service
[Unit]
Description=Lokal Coin daemon
After=network.target
[Service]
User=root
Group=root
Type=forking
PIDFile=/root/.lokalcoin/lokalcoin.pid
ExecStart=/root/LokalCoin/lokal_coind -daemon -pid=/root/.lokalcoin/lokalcoin.pid \
          -conf=/root/.lokalcoin/lokalcoin.conf -datadir=/root/.lokalcoin/
ExecStop=-/root/LokalCoin/lokal_coin-cli -conf=/root/.lokalcoin/lokalcoin.conf \
          -datadir=/root/.lokalcoin/ stop
Restart=always
RestartSec=20s
PrivateTmp=true
TimeoutStopSec=7200s
TimeoutStartSec=30s
StartLimitInterval=120s
StartLimitBurst=5
[Install]
WantedBy=multi-user.target
EOF
#enable the service
systemctl enable lokal.service
echo "lokal.service enabled"
#start the service
systemctl start lokal.service
echo "lokal.service started"
echo ""
echo "#################################"
echo "#      Installing sentinel      #"
echo "#################################"
echo ""
cd ~
set +e
#install python if missing, install pyhton 2.x virtualenv
apt-get -y install python python-virtualenv 
#install python3 virtualenv, if this version of python is used
apt-get -y install virtualenv git
git clone https://github.com/PACGlobalOfficial/sentinel
set -e
cd sentinel
virtualenv ./venv
./venv/bin/pip install -r requirements.txt
cat /etc/crontab | grep -v "* * * * * root cd ~/sentinel && ./venv/bin/python bin/sentinel.py >/dev/null 2>&1" > /etc/crontab2 && mv /etc/crontab2 /etc/crontab
echo "* * * * * root cd ~/sentinel && ./venv/bin/python bin/sentinel.py >/dev/null 2>&1" >> /etc/crontab
echo ""
echo "###############################"
echo "#      Running the wallet     #"
echo "###############################"
echo ""
echo "Please wait for 60 seconds!"
echo ""
sleep 60
is_lokal_running=`ps ax | grep -v grep | grep lokal_coind | wc -l`
if [ $is_lokal_running -eq 0 ]; then
	echo "The daemon is not running or there is an issue, please restart the daemon!"
	echo ""
	exit
fi
~/LokalCoin/lokal_coin-cli mnsync status
echo ""
echo "Your masternode wallet on the server has been setup and will be ready when the synchronization is done!"
echo ""
echo "Please execute following commands to check the status of your masternode:"
echo "~/LokalCoin/lokal_coin-cli -version"
echo "~/LokalCoin/lokal_coin-cli getblockcount"
echo "~/LokalCoin/lokal_coin-cli masternode status"
echo "~/LokalCoin/lokal_coin-cli mnsync status"
echo ""