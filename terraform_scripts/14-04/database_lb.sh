#!/bin/bash

# Define variables
export MASTER_IP="10.0.1.10"
export NAGIOS_SERVER_IP="10.0.1.14"
export IP_PGPOOL="10.0.1.13"
export SLAVE_IP="10.0.1.11"
export FLASK_IP="10.0.1.12"


# Update packages and install required packages
sudo apt-get update -y
sudo apt-get install -y pgpool2

sudo echo "nagios:quizztine" > /etc/pgpool2/pool_passwd


sudo bash -c "cat > /etc/pgpool2/pgpool.conf << EOF
listen_addresses = '*'
port = 5432
socket_dir = '/var/run/postgresql'
listen_backlog_multiplier = 2
serialize_accept = off
reserved_connections = 0
pcp_listen_addresses = '*'
pcp_port = 9898
pcp_socket_dir = '/var/run/postgresql'
backend_hostname0 = '$MASTER_IP'
backend_port0 = 5432
backend_weight0 = 1
backend_data_directory0 = '/var/lib/pgsql/data'
backend_flag0 = 'ALLOW_TO_FAILOVER'
backend_application_name0 = 'master0'
backend_hostname1 = '$SLAVE_IP'
backend_port1 = 5432
backend_weight1 = 1
backend_data_directory1 = '/var/lib/pgsql/data1'
backend_flag1 = 'ALLOW_TO_FAILOVER'
backend_application_name1 = 'slave0'
enable_pool_hba = off
pool_passwd = '/etc/pgpool2/pool_passwd'
authentication_timeout = 60
allow_clear_text_frontend_auth = off
ssl = off
ssl_ciphers = 'HIGH:MEDIUM:+3DES:!aNULL'
ssl_prefer_server_ciphers = off
ssl_ecdh_curve = 'prime256v1'
ssl_dh_params_file = ''
num_init_children = 32
max_pool = 4
child_life_time = 300
child_max_connections = 0
connection_life_time = 0
client_idle_limit = 0
log_destination = 'stderr'
log_line_prefix = '%t: pid %p: '   
log_connections = off
log_hostname = off
log_statement = off
log_per_node_statement = off
log_client_messages = off
log_standby_delay = 'none'
syslog_facility = 'LOCAL0'
syslog_ident = 'pgpool'
pid_file_name = '/var/run/postgresql/pgpool.pid'
logdir = '/var/log/postgresql'
connection_cache = on
reset_query_list = 'ABORT; DISCARD ALL'
replication_mode = off
replicate_select = off
insert_lock = on
lobj_lock_table = ''
replication_stop_on_mismatch = off
failover_if_affected_tuples_mismatch = off
load_balance_mode = on
ignore_leading_white_space = on
white_function_list = ''
black_function_list = 'currval,lastval,nextval,setval'
black_query_pattern_list = ''
database_redirect_preference_list = ''
app_name_redirect_preference_list = ''
allow_sql_comments = off
disable_load_balance_on_write = 'transaction'
statement_level_load_balance = off
master_slave_mode = on
master_slave_sub_mode = 'stream'
sr_check_period = 0
sr_check_user = 'nobody'
sr_check_password = ''
sr_check_database = 'postgres'
delay_threshold = 0
follow_master_command = ''
health_check_period = 0
health_check_timeout = 20
health_check_user = 'nobody'
health_check_password = ''
health_check_database = ''
health_check_max_retries = 0
health_check_retry_delay = 1
connect_timeout = 10000
failover_command = ''
failback_command = ''
failover_on_backend_error = on
detach_false_primary = off
search_primary_node_timeout = 300
auto_failback = off
auto_failback_interval = 60
recovery_user = 'nobody'
recovery_password = ''
recovery_1st_stage_command = ''
recovery_2nd_stage_command = ''
recovery_timeout = 90
client_idle_limit_in_recovery = 0
use_watchdog = off
trusted_servers = ''
ping_path = '/bin'
wd_hostname = ''
wd_port = 9000
wd_priority = 1
wd_authkey = ''
wd_ipc_socket_dir = '/tmp'
delegate_IP = ''
if_cmd_path = '/sbin'
if_up_cmd = '/usr/bin/sudo /sbin/ip addr add $_IP_$/24 dev eth0 label eth0:0'
if_down_cmd = '/usr/bin/sudo /sbin/ip addr del $_IP_$/24 dev eth0'
arping_path = '/usr/sbin'
arping_cmd = '/usr/bin/sudo /usr/sbin/arping -U $_IP_$ -w 1 -I eth0'
clear_memqcache_on_escalation = on
wd_escalation_command = ''
wd_de_escalation_command = ''
failover_when_quorum_exists = on
failover_require_consensus = on
allow_multiple_failover_requests_from_node = off
enable_consensus_with_half_votes = off
wd_monitoring_interfaces_list = ''  
wd_lifecheck_method = 'heartbeat'
wd_interval = 10
wd_heartbeat_port = 9694
wd_heartbeat_keepalive = 2
wd_heartbeat_deadtime = 30
heartbeat_destination0 = 'host0_ip1'
heartbeat_destination_port0 = 9694
heartbeat_device0 = ''
wd_life_point = 3
wd_lifecheck_query = 'SELECT 1'
wd_lifecheck_dbname = 'template1'
wd_lifecheck_user = 'nobody'
wd_lifecheck_password = ''
relcache_expire = 0
relcache_size = 256
check_temp_table = catalog
check_unlogged_table = on
enable_shared_relcache = on
relcache_query_target = master     
memory_cache_enabled = off
memqcache_method = 'shmem'
memqcache_memcached_host = 'localhost'
memqcache_memcached_port = 11211
memqcache_total_size = 67108864
memqcache_max_num_cache = 1000000
memqcache_expire = 0
memqcache_auto_cache_invalidation = on
memqcache_maxcache = 409600
memqcache_cache_block_size = 1048576
memqcache_oiddir = '/var/log/pgpool/oiddir'
white_memqcache_table_list = ''
black_memqcache_table_list = ''
EOF"

#MODIFY PG POOL HBA
sudo bash -c "cat >> /etc/pgpool2/pool_hba.conf << EOF
host    all         all         $FLASK_IP/32          trust
EOF"


sudo chown root:pgpool /etc/pgpool2/*
sudo chmod 640 /etc/pgpool2/*

sudo systemctl start pgpool2
sudo systemctl enable pgpool2
sudo sleep 25
sudo systemctl restart pgpool2