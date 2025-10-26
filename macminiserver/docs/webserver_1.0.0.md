# Mac Mini Webserver version 1.0.0

## Requirements

### General

- We want a stable setup that can serve static websites for the next decade with minimal maintenance needed.
- We want to serve multiple sites easily, including njoubert.com, lydiajoubert.com, zs1aaz.com, nielsshootsfilm.com, etc
- The webserver should be able to host my multiple websites and my multiple projects, including my njoubert.com home page which is just a static site, subdomains such as rtc.njoubert.com which is a WebRTC-based video streaming experiment, files.njoubert.com which is just a firestore, and nielsshootsfilm.com which is a hybrid static-dynamic site with a static frontend and a Go API.
- We want to make it easy to spin up additional static sites if needed.
- The design should use the available resources efficiently, it's only a Intel Core i3 Mac Mini with 3GB RAM.  
- The system should be fast, especially the static file serving.
- It should be dead simple to maintain as I am the only person maintaining this.
- It should keep the dependencies of different projects well-isolated. The last thing I want is to fight dependency hell between a 3 year old Wordpress website I am maintaining and a bleeding-edge Go app I am experimenting with.
- We want to be able to host Wordpress websites. 
- Wordpress websites should be well-isolated from all the other systems we might want to run, 
- We want to be able to host my dynamic projects as I dream up ideas over the next decade.
- We want good isolation between different projects.
- We want to be prepared if there is an influx of traffic, and use that well for the site that is getting the traffic while the other sites idle. So we do not want to, say, have a single thread or a single process per site! Something more dynamic is needed.
-  We want to have rate limiting and fail2ban on the root system to protect from attackers.
- We want to have good isolation between the different applications if one has a security vulnerability.


## Approach 1: bare metal nginx + docker containers.

The static sites are hosted directly by nginx. 

The dynamic sites are hosted in docker containers.  nginx reverse proxies to these containers.

Each wordpress site is in a docker container with its own mysql db.

Pros?

Cons?
