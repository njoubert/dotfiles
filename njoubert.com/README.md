# Configuration of njoubert.com


### 2020.12.26 Configuring Apache and MySQL for Small Server

My DigitalOcean Droplet is only 512Mb RAM and 20 GB Disk. 
This means that wordpress runs out of disk space every now and then

https://www.digitalocean.com/community/questions/mysql-server-keeps-stopping-unexpectedly
https://www.digitalocean.com/community/tutorials/how-to-add-swap-on-ubuntu-14-04

* Changed `/etc/mysql/my.cnf` to `innodb_buffer_pool_size = 20M`
* Changed `/etc/apache2/mods-enabled/mpm_prefork.conf`
* Enabled SWAP space https://www.digitalocean.com/community/tutorials/how-to-add-swap-on-ubuntu-14-04 
