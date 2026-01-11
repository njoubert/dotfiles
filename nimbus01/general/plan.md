# General Provisioning

- [X] ufw to block all incoming ports but 22, 80, 443, 3000
- [X] DNS resolver for 10.0.0.1 as cloudrest domain
- [X] Fail2Ban
- reasonable log rotation and limits, around 90 day retention
- [X] time synchronization

security:
- [X] enable unattended-upgrades automatically to get security patches
- [X] rootkit detection
- vulnerability scanning with trivy