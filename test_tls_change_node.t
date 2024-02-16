# -*- mode: ruby -*-
command_mode "docker"

nodes = ["s1.gluster", "s2.gluster"]
network = "gluster"

# Start three or N storage nodes(Containers)
command_node "local"
nodes.each do |node|
  command_node "local"
  command_run nil, "docker stop #{node}"
  command_run nil, "docker rm #{node}"
end

command_run nil, "docker network rm #{network}"
command_run "docker network create #{network}"

nodes.each do |node|
  command_node "local"
  command_run "docker run -d -v /sys/fs/cgroup/:/sys/fs/cgroup:ro --privileged --name #{node} --hostname #{node} --network #{network} aravindavk/gluster-node"
end

# Cleanup the glusterfs.ca file
command_node "local"
command_run "rm -f glusterfs.ca && touch glusterfs.ca"

# For each node, generate SSL key and certificate
nodes.each do |node|
  command_node node

  # Generate Private key (glusterfs.key)
  command_run "openssl genrsa -out /usr/lib/ssl/glusterfs.key 4096"

  # Generate the Certificate
  hostname = command_run "hostname -f"
  command_run "openssl req -new -x509 -key /usr/lib/ssl/glusterfs.key -subj \"/CN=#{hostname}\" -out /usr/lib/ssl/glusterfs.pem"

  # Create the secured-access file
  command_run "touch /var/lib/glusterd/secure-access"

  # Brick dir prepare
  command_run "mkdir -p /data/glusterfs/gv1"

  # Copy the cert file content and append to local glusterfs.ca file
  pem_content = command_run "cat /usr/lib/ssl/glusterfs.pem"
  command_node "local"
  command_run "echo '#{pem_content}' >> glusterfs.ca"
end

# Deploy glusterfs.ca file to all the nodes(servers and client nodes)
nodes.each do |node|
  command_node "local"
  command_run "docker cp glusterfs.ca #{node}:/usr/lib/ssl/glusterfs.ca"
end

# Start Glusterd in all the server nodes
nodes.each do |node|
  command_node node
  command_run "glusterd -LDEBUG"
end

# Create Gluster cluster and the Volume
# Enable the options needed for TLS
command_node nodes[0]
command_run "gluster peer probe #{nodes[1]}"
command_run "sleep 5"
command_run "gluster volume create gv1 replica 2 #{nodes[0]}:/data/glusterfs/gv1/b1 #{nodes[1]}:/data/glusterfs/gv1/b2 force"
command_run "gluster volume set gv1 client.ssl on"
command_run "gluster volume set gv1 server.ssl on"
command_run "gluster volume set gv1 auth.ssl-allow '*'"
command_run "gluster volume set gv1 ssl.cipher-list 'HIGH:!SSLv2'"
command_run "gluster volume start gv1"
command_run "gluster volume status gv1"

# Mount the Volume
command_node nodes[0]
command_run "sleep 5"
command_run "mkdir -p /mnt/gv1"
command_run "mount -t glusterfs #{nodes[0]}:gv1 /mnt/gv1"

# IO Test: Create a file and check that file exists in all the server nodes
command_run "echo 'Hello World!' > /mnt/gv1/f1"

# Check if the file exists in the first server
command_node nodes[0]
content = command_run "cat /data/glusterfs/gv1/b1/f1"
compare_equal? content, "Hello World!\n"

# Check if the file exists in the second server
command_node nodes[1]
content = command_run "cat /data/glusterfs/gv1/b2/f1"
compare_equal? content, "Hello World!\n"

# Stop Server 2 and remove
command_node "local"
command_run nil, "docker stop #{nodes[1]}"
command_run nil, "docker rm #{nodes[1]}"

# Remove brick and remove peer (Note: The node is not reachable)
command_node nodes[0] do
  command_run "gluster --mode=script volume remove-brick gv1 replica 1 #{nodes[1]}:/data/glusterfs/gv1/b2 force"
  command_run "gluster --mode=script peer detach #{nodes[1]} force"
end

# Start fresh node with the same hostname
command_run "docker run -d -v /sys/fs/cgroup/:/sys/fs/cgroup:ro --privileged --name #{nodes[1]} --hostname #{nodes[1]} --network #{network} aravindavk/gluster-node"

# Generate SSL key and Certificate freshly on node 2
command_node nodes[1]

# Generate Private key (glusterfs.key)
command_run "openssl genrsa -out /usr/lib/ssl/glusterfs.key 4096"

# Generate the Certificate
hostname = command_run "hostname -f"
command_run "openssl req -new -x509 -key /usr/lib/ssl/glusterfs.key -subj \"/CN=#{hostname}\" -out /usr/lib/ssl/glusterfs.pem"

# Create the secured-access file
command_run "touch /var/lib/glusterd/secure-access"

# Brick dir prepare
command_run "mkdir -p /data/glusterfs/gv1"

# Create a fresh glusterfs.ca file and copy from all nodes
command_node "local"
command_run "rm -f glusterfs.ca && touch glusterfs.ca"

# Copy the cert file content and append to local glusterfs.ca file
nodes.each do |node|
  command_node node
  pem_content = command_run "cat /usr/lib/ssl/glusterfs.pem"

  command_node "local"
  command_run "echo '#{pem_content}' >> glusterfs.ca"
end

# Deploy glusterfs.ca file to all the nodes(servers and client nodes)
nodes.each do |node|
  command_node "local"
  command_run "docker cp glusterfs.ca #{node}:/usr/lib/ssl/glusterfs.ca"
end

# Start Glusterd in Node 2
command_node nodes[1]
command_run "glusterd -LDEBUG"

# Add brick again and check the status
command_node nodes[0]
command_run "gluster peer probe #{nodes[1]}"
command_run "sleep 5"
command_run "gluster --mode=script volume add-brick gv1 replica 2 #{nodes[1]}:/data/glusterfs/gv1/b2 force"
command_run "gluster volume status"

# IO test again
# IO Test: Create a file and check that file exists in all the server nodes
command_run "echo 'Hello World!' > /mnt/gv1/f2"

# Check if the file exists in the first server
command_node nodes[0]
content = command_run "cat /data/glusterfs/gv1/b1/f2"
compare_equal? content, "Hello World!\n"

# Check if the file exists in the second server
command_node nodes[1]
content = command_run "cat /data/glusterfs/gv1/b2/f2"
compare_equal? content, "Hello World!\n"
