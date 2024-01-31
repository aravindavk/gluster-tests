FROM debian:12

RUN apt-get update -y
RUN apt-get install -y curl sudo gpg

RUN curl https://download.gluster.org/pub/gluster/glusterfs/10/rsa.pub | gpg --dearmor > /usr/share/keyrings/glusterfs-archive-keyring.gpg

# ENV DEBID=$(grep 'VERSION_ID=' /etc/os-release | cut -d '=' -f 2 | tr -d '"')
# ENV DEBVER=$(grep 'VERSION=' /etc/os-release | grep -Eo '[a-z]+')
# ENV DEBARCH=$(dpkg --print-architecture)

RUN echo "deb [signed-by=/usr/share/keyrings/glusterfs-archive-keyring.gpg] https://download.gluster.org/pub/gluster/glusterfs/10/LATEST/Debian/$(grep 'VERSION_ID=' /etc/os-release | cut -d '=' -f 2 | tr -d '"')/$(dpkg --print-architecture)/apt $(grep 'VERSION=' /etc/os-release | grep -Eo '[a-z]+') main" | sudo tee /etc/apt/sources.list.d/gluster.list

RUN apt-get update -y && apt-get install -y glusterfs-server

ENTRYPOINT ["tail", "-f", "/dev/null"]
