# -*- mode: ruby -*-
command_mode "docker"

nodes = ["c01.gluster", "c02.gluster", "c03.gluster", "cluster-client.gluster"]
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

command_node "local"
command_run "rm -f glusterfs.ca && touch glusterfs.ca"

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
nodes[0..2].each do |node|
  command_node node
  command_run "glusterd -LDEBUG"
end

# Create Gluster cluster and the Volume
# Enable the options needed for TLS
command_node nodes[0]
command_run "gluster peer probe #{nodes[1]}"
command_run "gluster peer probe #{nodes[2]}"
command_run "sleep 5"
command_run "gluster volume create gv1 replica 3 #{nodes[0]}:/data/glusterfs/gv1/b1 #{nodes[1]}:/data/glusterfs/gv1/b2 #{nodes[2]}:/data/glusterfs/gv1/b3 force"
command_run "gluster volume set gv1 client.ssl on"
command_run "gluster volume set gv1 server.ssl on"
command_run "gluster volume set gv1 auth.ssl-allow '*'"
command_run "gluster volume set gv1 ssl.cipher-list 'HIGH:!SSLv2'"
command_run "gluster volume start gv1"
command_run "gluster volume status gv1"

# Mount the Volume
command_node nodes[3]
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

# Check if the file exists in the third server
command_node nodes[2]
content = command_run "cat /data/glusterfs/gv1/b3/f1"
compare_equal? content, "Hello World!\n"
