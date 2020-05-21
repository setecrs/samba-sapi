#!/bin/bash -e

if [ ! -e /var/lib/samba/private/secrets.tdb ]
then
  : ${SID?-SID not set}
  : ${LDAPSECRET?-LDAPSECRET not set}
  net setlocalsid $SID
  smbpasswd -w $LDAPSECRET
fi

cat > /etc/samba/smb.conf <<EOF
[global]
        workgroup = ${WORKGROUP?-WORKGROUP not set}
        passdb backend = ldapsam:"${LDAP_URL?-LDAP_URL not set. Example: ldap://ldap01.localdomain}"
        client NTLMv2 auth = Yes
        ntlm auth = Yes
        client lanman auth = No
        client plaintext auth = No
        log level = 1
        log file = /var/log/samba/%U.log
        unix extensions = No
        load printers = No
        printcap name = /dev/null
        disable spoolss = Yes
        show add printer wizard = No
        add user script = /usr/sbin/smbldap-useradd -m "%u"
        add group script = /usr/sbin/smbldap-groupadd -p "%g"
        add user to group script = /usr/sbin/smbldap-groupmod -m "%u" "%g"
        delete user from group script = /usr/sbin/smbldap-groupmod -x "%u" "%g"
        set primary group script = /usr/sbin/smbldap-usermod -g "%g" "%u"
        add machine script = /usr/sbin/smbldap-useradd -w "%u"
        ldap admin dn = ${LDAP_ADMIN_DN?-LDAP_ADMIN_DN not set}
        ldap delete dn = Yes
        ldap group suffix = ou=Group
        ldap machine suffix = ou=Computers
        ldap user suffix = ou=People
        ldap passwd sync = Yes
        ldap suffix = ${LDAP_SUFFIX?-LDAP_SUFFIX not set}
        ##disables TLS, with ldaps will use ssl instead
        ldap ssl = off
        template homedir = /home/%U
        wide links = yes
        hide unreadable = yes
        veto files = /desktop.ini/
        socket options = TCP_NODELAY IPTOS_LOWDELAY SO_KEEPALIVE 
        fake oplocks = yes
        dead time = 2
        keepalive = 10

[homes]
        comment = Home Directories
        path = /home/%u/Desktop/
        create mask = 0755
        directory mask = 0755
        browseable = No
        locking = no
EOF

exec "$@"
