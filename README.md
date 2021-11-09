# SimpleDomainBackup
Bash script to backup website files with database and store archive on remote ftp

Script copied on quickly from pop-up notes. Check carefully before use :) 

## How to use

First edit the file and provide the necessary settings

### Doing backup:


#### to start backup of files and database:
./backup.sh start

#### to see list previously made backups saved on remote host
./backup.sh list

#### to download previously made backups
./backup.sh get filename.zip
