#!/bin/bash -e

: ${LDAP_ADMIN_PASSWORD?-LDAP_ADMIN_PASSWORD not set}
: ${LDAP_BASE_DN?-LDAP_BASE_DN not set}
: ${LDAP_SERVER?-LDAP_SERVER not set}
: ${WORKGROUP?-WORKGROUP not set}
: ${READ_ONLY?-READ_ONLY not set}
HIDE_UNREADABLE=${HIDE_UNREADABLE:-no}
if [ "${VALID_USERS}" != "" ]
then
  LINE_VALID_USERS="valid users = ${VALID_USERS}"
fi

cat > /etc/samba/smb.conf <<EOF
[global]
        workgroup = ${WORKGROUP}
        passdb backend = ldapsam:"ldap://${LDAP_SERVER}"
        client NTLMv2 auth = Yes
        ntlm auth = Yes
        client lanman auth = No
        client plaintext auth = No
        log level = 2
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
        ldap admin dn = cn=admin,${LDAP_BASE_DN}
        ldap delete dn = Yes
        ldap group suffix = ou=Group
        ldap machine suffix = ou=Computers
        ldap user suffix = ou=People
        ldap passwd sync = Yes
        ldap suffix = ${LDAP_BASE_DN}
        ##disables TLS, with ldaps will use ssl instead
        ldap ssl = off
        template homedir = /home/%U
        wide links = yes
        dead time = 15

[homes]
        read only = ${READ_ONLY}
        comment = Home Directories
        path = /home/%u/Desktop/
        create mask = 0777
        directory mask = 0777
        browseable = No
        hide unreadable = ${HIDE_UNREADABLE}
        ${LINE_VALID_USERS}
EOF

cat > /etc/smbldap-tools/smbldap.conf <<EOF
slaveLDAP="${LDAP_SERVER}"
masterLDAP="${LDAP_SERVER}"
verify="none"
cafile=""
clientcert=""
clientkey=""
suffix="${LDAP_BASE_DN}"
usersdn="ou=People,\${suffix}"
computersdn="ou=Computers,\${suffix}"
groupsdn="ou=Group,\${suffix}"
idmapdn="ou=Idmap,\${suffix}"
sambaUnixIdPooldn="sambaDomainName=${WORKGROUP},\${suffix}"
scope="sub"
hash_encrypt="CRYPT"
crypt_salt_format="\$6\$%s"
userLoginShell="/bin/false"
userHome="/home/%U"
userHomeDirectoryMode="700"
userGecos="System User"
defaultUserGid="513"
defaultComputerGid="515"
skeletonDir="/etc/skel"
defaultMaxPasswordAge="45"
userScript=""
mailDomain=""
with_smbpasswd="0"
smbpasswd="/usr/bin/smbpasswd"
with_slappasswd="0"
slappasswd="/usr/sbin/slappasswd"
EOF

cat > /etc/smbldap-tools/smbldap_bind.conf <<EOF
slaveDN="cn=admin,${LDAP_BASE_DN}"
slavePw="${LDAP_ADMIN_PASSWORD}"
masterDN="cn=admin,${LDAP_BASE_DN}"
masterPw="${LDAP_ADMIN_PASSWORD}"
EOF

cat > /etc/sssd/sssd.conf <<EOF
[domain/default]

autofs_provider = ldap
enumerate = True
cache_credentials = True
krb5_realm = #
ldap_search_base = dc=setecrs,dc=dpf,dc=gov,dc=br
id_provider = ldap
auth_provider = ldap
chpass_provider = ldap
ldap_uri = ldap://${LDAP_SERVER}/
ldap_tls_cacertdir = /etc/openldap/cacerts
ldap_id_use_start_tls = False
entry_cache_timeout = 5
ldap_default_bind_dn = cn=admin,${LDAP_BASE_DN}
ldap_default_authtok_type = password
ldap_default_authtok = ${LDAP_ADMIN_PASSWORD}

[sssd]
services = nss, pam, autofs
config_file_version = 2
domains = default

[nss]
enum_cache_timeout = 0
entry_negative_timeout = 0
memcache_timeout = 0

[pam]

[sudo]

[autofs]

[ssh]

[pac]
EOF

chmod 600 /etc/sssd/sssd.conf

if [ -e /var/run/sssd.pid ]
then
  SSSDPID=`cat /var/run/sssd.pid`
  # test if the process died
  if kill -0 $SSSDPID 2>/dev/null
  then
    echo -n
  else
    rm /var/run/sssd.pid
    sssd -D
  fi
else # /var/run/sssd.pid does not exist
  sssd -D
fi

if [ ! -e /var/lib/samba/private/secrets.tdb ]
then
  : ${SID?-SID not set}
  net setlocalsid $SID
  smbpasswd -w $LDAP_ADMIN_PASSWORD
fi

COUNT=0
while (( `curl ${LDAP_SERVER}:389; echo $?` == 7 )) # 7: connection refused
do
  echo Waiting for ldap
  sleep 0.1
  if (( COUNT++ > 10 ))
  then
    echo ldap unavailable
    exit 1
  fi
done

# different passwords on purpose, so we don't change the root password
#(echo 1; echo 2) | smbldap-populate

exec "$@"
