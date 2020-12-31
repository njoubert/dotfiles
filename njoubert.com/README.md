# Configuration of njoubert.com

### 2020.12.31

MySQL root password reset. MySQL plus sudo. 

### 2020.12.26 

configured tmux and added symlinks

We gonna setup HTTPS!!! https://www.digitalocean.com/community/tutorials/how-to-create-a-self-signed-ssl-certificate-for-apache-in-ubuntu-16-04

This works but of course there's a whole bunch of error messages since it is self-signed. That's okay.




### 2020.12.26 Configuring Apache and MySQL for Small Server

My DigitalOcean Droplet is only 512Mb RAM and 20 GB Disk. 
This means that wordpress runs out of disk space every now and then

https://www.digitalocean.com/community/questions/mysql-server-keeps-stopping-unexpectedly
https://www.digitalocean.com/community/tutorials/how-to-add-swap-on-ubuntu-14-04

* Changed `/etc/mysql/my.cnf` to `innodb_buffer_pool_size = 20M`
* Changed `/etc/apache2/mods-enabled/mpm_prefork.conf`

If it gets worse, we'll enabled SWAP space https://www.digitalocean.com/community/tutorials/how-to-add-swap-on-ubuntu-14-04 

## Mosh

Much better than SSH. https://mosh.org/

`apt-get install mosh`
`sudo ufw allow 60000:61000/udp`
