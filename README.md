# gluster-tests

Collection of Gluster Tests

## Setup

Install Kadalu Binnacle tool

```
gem install kadalu-binnacle
```

Install Docker to run the tests.

## Usage

### Gluster TLS Tests

Build the Gluster Storage docker image (For testing I used Debian 12 and Gluster 10)

```
cd gluster-tests/
sudo bash -x build.sh
```

Now run the TLS tests:

- Creates 3 servers and 1 client node (`c01.gluster`, `c02.gluster`, `c03.gluster` and `cluster-client.gluster`)
- Create Private key and certificates in all nodes
- Create Gluster cluster and create a Volume (`gv1`)
- Enable the TLS options
- Mount the volume and verify by creating a sample file

```
$ sudo binnacle -vv test_tls.t
...
STATUS  TOTAL  PASSED  FAILED  DURATION  SPEED(TPM)  FILE
==================================================================
OK         70      70       0        1m          62  test_tls.t

Test Files: Total=1  Passed=1  Failed=0
```

## Gluster TLS with Node replacement test

- Create cluster with 2 servers (`server1.gluster` and `server2.gluster`)
- SSL based setup
- Simulate the node failure (`server2.gluster`)
- Remove brick and detach the peer
- Setup fresh node using the same hostname
- Setup SSL key and Certificate in the new node
- Copy the fresh certificates from all the nodes and create `glusterfs.ca` file
- Peer probe and add brick

```
$ sudo binnacle -vv test_tls_change_node.t 
STATUS  TOTAL  PASSED  FAILED  DURATION  SPEED(TPM)  FILE
==================================================================
OK         71      71       0        1m          63  test_tls_change_node.t

Test Files: Total=1  Passed=1  Failed=0
```
