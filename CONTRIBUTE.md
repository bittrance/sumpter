
Installing a postfix and enabling authentication:

```sh
apt-get install sasl2-bin postfix
mkdir /etc/sasl2
echo > /etc/sasl2/smtpd.conf <<<EOF
pwcheck_method: auxprop
auxprop_plugin: sasldb
mech_list: PLAIN LOGIN CRAM-MD5 DIGEST-MD5
EOF
postconf -e smtpd_sasl_auth_enable=yes
postconf -h mydomain
saslpasswd2 -c -u example.com dauser
cp /etc/sasldb2 /var/spool/postfix/etc/
chgrp postfix /var/spool/postfix/etc/sasldb2
service postfix restart
```

Verifying your auth:

```ruby
require 'base64'
Base64.strict_encode64("dauser@example.com\0dauser@example.com\0secret")
```
