FROM fedora:31

RUN dnf --disablerepo=\* --enablerepo=fedora install -y samba smbldap-tools sssd-ldap \
 && dnf clean all

ENV LANG=C.UTF-8

COPY entrypoint.sh /
ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash", "-c", "smbd --foreground --log-stdout --no-process-group < /dev/null"]

EXPOSE 445
