Industrializing a Flask app to attain high availability, scalability, security and reliability. 

- Terraform for automated deployment of Ubuntu VMs (Azure). 
- Front-end : Loadbalancer/ReverseProxy NginX 
- Back-end : 2 Apache webservers, 1 Monitoring server (Nagios, Prometheus), Database Load-balancer using PgPool-II, Master & Slave databases on different VMs (with streaming replication). 

Tech used : 
 
- Databases : PostgreSQL, repmgr, patroni, haproxy, pgpool-II, psycopg2, backups (using pg_dump/dumpall) to an azure managed disk.
- Monitoring : Nagios, NRPE, Prometheus, Loki, Grafana 
- Webservers : Apache, NGINX 
- Bash scripting : Dozens of .sh auto-install scripts, backups scripts, cronjobs 

Fully automated deployment with Terraform + Ansible
