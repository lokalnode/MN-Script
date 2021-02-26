# LOKALCoin Masternode Setup Guide:

This guide assumes you are setting up a single mainnet masternode for the first time. You will need: 

- 20,000 LOKAL
- A wallet to store your LOKAL.
- A Linux server, preferably a Virtual Private Server (VPS).



Select Ubuntu 18.04 x64 as the server type. We use this LTS release of Ubuntu instead of the latest version because LTS releases are supported with 
security updates for 5 years, instead of the usual 9 months.

## Sending the collateral:

Open LOKALCoin wallet and wait for it to synchronize with the network. It should look like this when ready:

Click Tools > Debug console to open the console. Type the following command into the console to generate a new LOKALCoin address for the collateral: `getnewaddress`


Take note of the collateral address, since we will need it later. The next step is to secure your wallet (if you have not already done so). 
First, encrypt the wallet by selecting Settings > Encrypt wallet. You should use a strong, new password that you have never used somewhere else. 
Take note of your password and store it somewhere safe or you will be permanently locked out of your wallet and lose access to your funds. 
Next, back up your wallet file b y selecting File > Backup Wallet. Save the file to a secure location physically separate to your computer, 
since this will be the only way you can access our funds if anything happens to your computer.

Now send exactly 20,000 LOKAL in a single transaction to the new address you generated in the previous step. This may be sent from another wallet, or from funds already held in your current wallet. You will need 15 confirmations before you can register the masternode, 
but you can continue with the next step at this point already: generating your masternode operator key.

Generate a BLS key pair:
A public/private BLS key pair is required to operate a masternode - for each masternode one needs one key pair. 
The private key is specified on the masternode itself, and allows it to be included in the deterministic masternode list once a provider registration transaction with the 
corresponding public key has been created.

If you are using a hosting service, they may provide you with their public key, and you can skip this step. If you are hosting your own masternode or have agreed to 
provide your host with the BLS private key, generate a BLS public/private keypair in LOKALCoin Core by clicking Tools > Debug console and entering the following command: 
`bls generate`

These keys are NOT stored by the wallet and must be kept secure.

## Install LokalCoin on a VPS:

To install LOKALCoin using the install script, enter the following commands after logging in:

`wget -N https://raw.githubusercontent.com/lokalnode/MN-Script/master/lokal-mn.sh && chmod +x lokal-mn.sh && 
./lokal-mn.sh lokalcoin-ubuntu-daemon https://github.com/lokalnode/LokalCoin/releases/download/v1.0/lokalcoin-ubuntu-daemon.tar.gz`



This will setup the basic firewall settings, create a swapfile, download and install the latest version on LOKALCoin for your system, automatically configure the masternode and create a systemctl service.

You will be prompted to enter your masternodeblsprivkey. You have this saved from the previous step, this is your private bls key.

We now need to wait for 15 confirmations of the collateral transaction to complete, and wait for the blockchain to finish synchronizing on the masternode. 
You can use the following commands to monitor progress:

`~/LokalCoin/lokal_coin-cli mnsync status`

When synchronisation is complete, Continue with the next step to construct the ProTx transaction required to enable your masternode.


## Register your masternode:

If you used an address in LOKALCoin wallet for your collateral transaction, you now need to find the txid of the transaction. 
Click Tools > Debug console and enter the following command: `masternode outputs`

This should return a string of characters.
The first long string is your collateralHash, while the last number is the collateralIndex.

A pair of BLS keys for the operator were already generated above, and the private key was entered on the masternode. The public key is used in this transaction as the operatorPubKey.

First, we need to get a new, unused address from the wallet to serve as the owner key address (ownerKeyAddr). This is not the same as the collateral address holding 20,000 LOKAL. 
Type the following command into the console to generate a new LOKALCoin address: `getnewaddress`


This address can also be used as the voting key address (votingKeyAddr). Alternatively, you can specify an address provided to you by your chosen voting delegate, or simply generate a new voting key address. 
Type the following command into the console to generate a new LOKALcoin: `getnewaddress`

Then either generate or choose an existing address to receive the owner's masternode payouts (payoutAddress). It is also possible to use an address external to the wallet. 
Type the following command into the console to generate a new LOKLACoin address: `getnewaddress`

You can also optionally generate and fund another address as the transaction fee source (feeSourceAddress). If you selected an external payout address, 
you must specify a fee source address. Either the payout address or fee source address must have enough balance to pay the transaction fee, or the final register_submit transaction will fail.


The private keys to the owner and fee source addresses must exist in the wallet submitting the transaction to the network. If your wallet is protected by a password, it must now be unlocked to perform the following commands. 
Unlock your wallet for 5 minutes: `walletpassphrase yourSecretPassword 300`


## Preparing a ProRegTX transaction:

We will now prepare an unsigned ProRegTx special transaction using the protx register_prepare command. This command has the following syntax:

protx register_prepare collateralHash collateralIndex ipAndPort ownerKeyAddr operatorPubKey votingKeyAddr operatorReward payoutAddress (feeSourceAddress)

Open a text editor such as notepad to prepare this command. Replace each argument to the command as follows:

- collateralHash: The txid of the 20,000 LOKAL collateral funding transaction (long output from masternode outputs)
- collateralIndex: The output index of the 20,000 LOKAL funding transaction (short output from masternode outputs)
- ipAndPort: Masternode IP address and port, in the format x.x.x.x:yyyy
- ownerKeyAddr: The new LOKALCoin address generated above for the owner/voting address
- operatorPubKey: The BLS public key generated above (or provided by your hosting service)
- votingKeyAddr: The new LOKALCoin address generated above, or the address of a delegate, used for proposal voting
- operatorReward: The percentage of the block reward allocated to the operator as payment. If you are setting your own masternode on your own VPS, the value should be 0.
- payoutAddress: A new or existing LOKALCoin address to receive the owner's masternode rewards
- feeSourceAddress: An (optional) address used to fund ProTx fee. payoutAddress will be used if not specified.

Note 1: You will need to have enough funds in payoutaddress to cover transaction fee. So add 100-200 LOKAL there.
Note 2: For the above command to work there has to be exactly one space between each entry.
Note 3: Ownerkeyaddr and votingkeyaddr do not need to be the same
Note 4: That the operator is responsible for specifying their own reward address in a separate update_service transaction if you specify a non-zero operatorReward. The owner of the masternode collateral does not specify the operator's payout address.


Paste your prepared command in the debug console this will give 3 outputs: TX, CollateralAddress and SignMessage

Next we will use the collateralAddress and signMessage fields to sign the transaction, and the output of the tx field to submit the transaction.

## Signing the ProRegTX transaction:

We will now sign the content of the signMessage field using the private key for the collateral address as specified in collateralAddress.
Note that no internet connection is required for this step, meaning that the wallet can remain disconnected from the internet in cold storage to sign the message. 
In this example we will again use LOKALCoin. The command takes the following syntax:
signmessage collateralAddress signMessage

This command will generate a sig hash.


## Submitting the signed message:

We will now submit the ProRegTx special transaction to the blockchain to register the masternode. 
This command must be sent from a LOKALCoin wallet holding a balance on either the feeSourceAddress or payoutAddress, since a standard transaction fee is involved.
The command takes the following syntax:
protx register_submit tx sig

Where:
- tx: The serialized transaction previously returned in the tx output field from the protx register_prepare command.
- sig: The message signed with the collateral key from the signmessage command. (output from the signmessage command)

Your masternode is now registered.
You can view this list on the Masternodes tab on LOKALCoin wallet, or in the console using the command protx list valid, where the txid of the final protx register_submit transaction identifies your masternode.

At this point you can go back to your terminal window and monitor your masternode using 

`~/LokalCoin/lokal_coin-cli masternode status`

At this point you can safely log out of your server by typing exit. 
Congratulations! Your masternode is now running.
