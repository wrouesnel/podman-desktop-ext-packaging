FROM docker.io/library/almalinux:10
RUN dnf -y install rpm-build findutils && dnf clean all
