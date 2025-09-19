# njoubert.com

## TL;DR:

```
IP: 137.184.90.253
users: root njoubert
mysql root password: /root/.digitalocean_password
```

#### Setting up a new site

* Register domain
* [Point domain nameservers](https://www.digitalocean.com/community/tutorials/how-to-point-to-digitalocean-nameservers-from-common-domain-registrars) to `ns[1,2,3].digitalocean.com` 
* Setup domain in DigitalOcean with one `A` record point to server, two `CNAME` records for `www` and `*` and three `NS` records for `ns[1,2,3].digialocean.com`
* On server, clone one of the other `/etc/apache2/sites-available/*.conf` and change config for this new domain
* Create root directory for website in `/var/www/`
* Wait for DNS to percolate
* Use certbot to get DNS: `sudo certbot certonly --dns-digitalocean --dns-digitalocean-credentials /home/njoubert/certbot-creds.ini -d "*.zs1aaz.com" -d "zs1aaz.com"`
* Reload apache `systemctl reload apache2`

#### Apache

```
`njoubert` is part of `www-data`. 
Sites live in /var/www
We use apache virtual hosts in /etc/apache2/sites-available

Useful commands:
- a2ensite
- a2dissite
- apache2ctl configtest
- systemctl restart apache2

```
#### Certbot

Check on [Certbot](https://certbot.eff.org/docs/using.html): 
```
Usefil commands:
- sudo systemctl status certbot.timer`
- sudo certbot renew --dry-run
- sudo certbot certonly --dns-digitalocean --dns-digitalocean-credentials /home/njoubert/certbot-creds.ini -d "*.zs1aaz.com" -d "zs1aaz.com"

```
# Journal

## 2022-08-04 Got Hacked

Looks like spambots and scriptkids blasted my MySQL instance with a bunch of crap. I disabled PhP and killed MySQL, upgraded to a bigger instance. Now njoubert.com is back but the databases are messed up.

Getting mysql back up
```
Delete the undo files. 
Changed my.cnf to have tread_stack of 512000
tail -f /var/log/mysql/error.log
systemctl start mysql
see the upgrade go through and things launch
```
OK, we're back in. PHP is still disabled, that' good. 

mysql> show databases;
+--------------------+
| Database           |
+--------------------+
| information_schema |
| mysql              |
| performance_schema |
| sys                |
| wplydiajoubert     |
| wpzs1aaz           |
+--------------------+


OK we better back things up now that we're up and running again. First we just dump things please. Then we figure out if something has balooned. 

```
mysqldump -u root -p wpzs1aaz > mysql_wpzs1aaz_post-hack-backup.sql
mysqldump -u root -p wplydiajoubert > mysql_wplydiajoubert_post-hack-backup.sql
tar -czf backup-2022-08-webserver-www.tar.gz /var/www/
```
Copy all this stuff down locally. OK, now we can look into what the heck happened here.



## 2021-09-11: MySQL is taking up a lot of memory still


INSERT INTO wp_users (user_login,user_pass,user_nicename,user_email,user_url,user_registered,user_activation_key,user_status,display_name) VALUES ('njoubert',MD5('rsd887'),'njoubert','njoubert@gmail.com','http://localhhost','2021-08-27','',0,'njoubert');

INSERT INTO wp_usermeta (umeta_id,user_id,meta_key,meta_value) VALUES (NULL, '2', 'wp_capabilities', 'a:1:{s:13:"administrator";b:1;}'), (NULL, '2', 'wp_user_level', '10'), (NULL, '2', 'show_welcome_panel', '1'); 


## 2021-09-09

Decided to do a fresh server and migrate my old njoubert.com to this new server. The previous server was running Ubuntu 14.04 with old versions of everything, and it seems easier and cleaner to start up a fresh server.

References:
* [DigitalOcean Wordpress Droplet](https://marketplace.digitalocean.com/apps/wordpress)
* [DigitalOcean LAMP Droplet](https://marketplace.digitalocean.com/apps/lamp)


### Starting with Default DigitalOcean LAMP Stack

Link: https://marketplace.digitalocean.com/apps/lamp

Included Software:
* Apache 2.4.41
* MySQL server 8.0.21
* PHP 8.0
* Fail2ban 0.11.1
* Postfix 3.4.10
* Certbot 0.39.0

Default Configuration
* Enables the UFW firewall to allow only SSH (port 22, rate limited), HTTP (port 80), and HTTPS (port 443) access.
* Sets the MySQL root password and runs mysql_secure_installation.
* Sets up the debian-sys-maint user in MySQL so the system’s init scripts for MySQL will work without requiring the MySQL root user password.

### My Configuration

I added my SSH keys through the droplet creation panel initially. 


#### Create a new user. 

```
ssh root@137.184.90.253
adduser njoubert
usermod -aG sudo njoubert
cp .ssh/authorized_keys /home/njoubert/.ssh/
chown njoubert:njoubert /home/njoubert/.ssh/authorized_keys
usermod -a -G www-data njoubert
```


#### Setup Apache for njoubert.com

[Tutorial]( https://www.digitalocean.com/community/tutorials/how-to-set-up-apache-virtual-hosts-on-ubuntu-16-04)

Previously we were using subdirectories-as-vhosts but this makes us a little inflexible, we cannot do custom apache configurations for different sites. Let's just use Apache virtual hosts properly. 

* Each website will live under /var/www/*
* Subdirectories should be the prefixes. So http://2018.nimbus.wtf/ should live at /var/www/nimbus.wtf/2018/ The default should be www


I create a directory structure with njoubert.com and nimbus.wtf under /var/www

```bash
sudo chmod -R 775 /var/www
```

Disable default host
```bash
sudo a2dissite 000-default.conf
apache2ctl configtest
systemctl reload apache2
```

Enable a few useful mods
```bash
a2enmod rewrite vhost_alias
apache2ctl configtest
systemctl restart apache2
```

##### www.njoubert.com -> njoubert.com and Subdirectories as Subdomains

I like having subdomains as subdirectories. 
and I also like that you can go directly to njoubert.com and get data. 

There's a few ways of doing this. I'm using www.njoubert.com as my default and redirect njoubert.com to is. Then all other subdomains are generated using vhost_alias.

Previously, I was doing a Rewrite rule that globally rewrote any address that comes in into a set of subdirectories, but that meant that I only really had a single virtual host in apache, which was inflexible. 

https://www.simplified.guide/apache/redirect-to-www


See /etc/apache2/sites-available/njoubert.com.conf

##### Flip over domains

Change njoubert.com entry on digitalocean command panel. 
Make sure there is two A records:
```
A        njoubert.com        137.184.90.253
A        www.njoubert.com    137.184.90.253
```

##### *DO NOT DO THIS* Setup LetsEncrypt/CertBot for Apache

[Tutorial](https://www.digitalocean.com/community/tutorials/how-to-secure-apache-with-let-s-encrypt-on-ubuntu-20-04)
]
```
sudo certbot --apache
```

This uses a [HTTP-01 challenge](https://letsencrypt.org/docs/challenge-types/) to confirm that we own the server and domain. This works great.... but doesn't support wildcards! So we do the next:

##### Setup Wildcard Certs with LetsEncrypt with DNS

https://www.digitalocean.com/community/tutorials/how-to-create-let-s-encrypt-wildcard-certificates-with-certbot


This won't use the Apache plugin, this will use a DNS-based plugin. Beats me why.  Make sure there is an DNS "A" record for `*.njoubert.com`

`sudo apt install python3-certbot-dns-digitalocean`

Get my digitalocean API key from here: https://cloud.digitalocean.com/account/api/tokens?i=69a706

Place in `/home/njoubert/certbot-creds.ini`

Pull certs:

`sudo certbot certonly --dns-digitalocean --dns-digitalocean-credentials /home/njoubert/certbot-creds.ini -d "*.njoubert.com" -d "njoubert.com"`

*what is going on here?* This does a [ACME challenge](https://letsencrypt.org/docs/challenge-types/) to verify that we control the domain. It does this by adding a magic string to our DNS using the DigitalOcean token.

Certs saved in:
```
/etc/letsencrypt/live/njoubert.com/fullchain.pem
/etc/letsencrypt/live/njoubert.com/privkey.pem
```

Try the neweal:
`sudo certbot renew --dry-run`
This FAILS because it can't find the certbot-creds.init

I edit `/etc/letsencrypt/renewal/njoubert.com.conf` and fix the path, and change the permissions on `/home/njoubert/certbot-certs.ini` to be root user read only. Let's hope this works.

OK, let's see if we can make Apache use this. Create `njoubert.com-ssl.conf` in /etc/apache2/sites-available

Done!

#### Get njoubert.com up on this apache install.

First we add the newly generated SSH keys for this server to our github.

clone to this server.
it works!
 I copy over all the subfolders and stuff

#### Get a second domain up and running - nimbus.wtf

Clone the nimbus.wtf repo from github.

configured a slightly different set of /etc/apache2/sites-enabled. You want to always redirect to ssl.

Enable both sites with `a2ensite`

`sudo certbot certonly --dns-digitalocean --dns-digitalocean-credentials /home/njoubert/certbot-creds.ini -d "*.nimbus.wtf" -d "nimbus.wtf"`

Wham, done. 

#### Get ZS1AAZ.com and lydiajoubert.com certs up as well



```
sudo certbot certonly --dns-digitalocean --dns-digitalocean-credentials /home/njoubert/certbot-creds.ini -d "*.lydiajoubert.com" -d "lydiajoubert.com"

sudo certbot certonly --dns-digitalocean --dns-digitalocean-credentials /home/njoubert/certbot-creds.ini -d "*.zs1aaz.com" -d "zs1aaz.com"

```

### Setting up zs1aaz.com

First configure the apache site by cloning njoubert.com and of course the certs is already there. 

Then download [wordpress 5.8.1](https://wordpress.org/download/) into /var/www/zs1aaz.com/www 

Log into mysql. Password is in /root/.digitalocean_password

```sql
CREATE DATABASE wpzs1aaz;
CREATE USER 'wpzs1aazuser'@'localhost' IDENTIFIED BY 'vi6eKdGs2pYq';
GRANT ALL PRIVILEGES ON wpzs1aaz.* TO 'wpzs1aazuser'@'localhost' WITH GRANT OPTION;
FLUSH PRIVILEGES;
```

Configure wp-config.php

Create three users:
```
njoubert
jTQzqR6bGqzC

zs1aaz
EuEEbtwyEP9Y

hendrikvh
RBq9dFQgkhra
```

Muck around with the template

### Change it so that the NAKED domain is the default. 

Redirect www.$1 to $1
The page is now /var/www/$1/$1/

### Hmm i broke zs1aaz.com to have sub-pages and stuff

The pretty links all fail. 
I needed to enable overrides, put this in zs1aaz.com.conf:

```
<Directory /var/www/zs1aaz.com/>
    Options Indexes FollowSymLinks
    AllowOverride All
    Require all granted
</Directory>
```

### Installing more software

Mosh

```bash
sudo apt-get install mosh
sudo ufw allow 60000:61000/udp
```

tmux
```bash
sudo apt-get install tmux

```

### Setup digitalocean monitoring agent

https://docs.digitalocean.com/products/monitoring/how-to/install-agent/

### Migrate lydiajoubert.com

Copy the wordpress files directly
Dump and then import the mysql database
Then add user to mysql

Looks like the wordpress version is so old it won't load here anymore, sad. 

### Change apache2 to spawn less instances and mysql to use less memory

We don't need to anticipate a million users. Just have 1 server running spare.
* Changed `/etc/apache2/mods-enabled/mpm_prefork.conf`
* Changed `/etc/mysql/my.cnf` to `innodb_buffer_pool_size = 20M`

https://docs.rackspace.com/support/how-to/configure-mysql-server-on-the-ubuntu-operating-system/
MySQL config lives in `/etc/my.cnf /etc/mysql/my.cnf ~/.my.cnf`



Really struggling to  get mysqld to use less memory, doesn't seem like anything has an effect


https://tech.labelleassiette.com/how-to-reduce-the-memory-usage-of-mysql-61ea7d1a9bd

```
+------------------------------------------+--------------------+
|                          key_buffer_size |          16.000 MB |
|                         query_cache_size |           0.000 MB |
|                  innodb_buffer_pool_size |         128.000 MB |
|          innodb_additional_mem_pool_size |           0.000 MB |
|                   innodb_log_buffer_size |          16.000 MB |
+------------------------------------------+--------------------+
|                              BASE MEMORY |         160.000 MB |
+------------------------------------------+--------------------+
|                         sort_buffer_size |           0.250 MB |
|                         read_buffer_size |           0.125 MB |
|                     read_rnd_buffer_size |           0.250 MB |
|                         join_buffer_size |           0.250 MB |
|                             thread_stack |           0.273 MB |
|                        binlog_cache_size |           0.031 MB |
|                           tmp_table_size |          16.000 MB |
+------------------------------------------+--------------------+
|                    MEMORY PER CONNECTION |          17.180 MB |
+------------------------------------------+--------------------+
|                     Max_used_connections |                  1 |
|                          max_connections |                151 |
+------------------------------------------+--------------------+
|                              TOTAL (MIN) |         177.180 MB |
|                              TOTAL (MAX) |        2754.133 MB |
+------------------------------------------+--------------------+
```




### Increase PHP maximum upload size

modify `/etc/php/8.0/apache2/php.ini` as follows:

```
upload_max_filesize = 64M
post_max_size = 64M

```


### Reduce Mysql8 memory footprint

[After reading](https://lefred.be/content/mysql-8-0-memory-consumption-on-small-devices/), I discoveded that one of the main drivers of MySQL 8 memory usage is the new Performance Schema. It does a lot of instrumentation to monitor MySQL. On my tiny little server this is surely not necessary so I'm disabling. This cuts from 334Mb to 128Mb quiescent memory usage.


