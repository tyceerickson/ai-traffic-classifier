this is the command to run all the scripts at the same time on a loop until manuall stopped. This allows time for all the attack scripts to run through their whole process with "normal generated traffic"

while true; do bash benign_web_traffic.sh; done & \
while true; do bash benign_dns_queries.sh; done & \
while true; do bash benign_ssh_session.sh; done & \
while true; do bash benign_file_transfer.sh; done & \
while true; do bash benign_ping_sweep.sh; done &

this command kills all the scripts once finished 

kill $(jobs -p)
