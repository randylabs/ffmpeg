#!/opt/homebrew/bin/fish

 act -j smoke \
    --bind \
    --container-daemon-socket /var/run/docker.sock \
    -P ubuntu-latest=catthehacker/ubuntu:act-latest
