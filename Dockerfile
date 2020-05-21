FROM fedora:31

RUN dnf --disablerepo=\* --enablerepo=fedora install -y samba smbldap-tools \
 && dnf clean all

ENV LANG=en_US.UTF-8

COPY entrypoint.sh /
ENTRYPOINT ["/entrypoint.sh"]
CMD ["smbd", "--foreground", "--log-stdout", "--no-process-group"]

EXPOSE 445
