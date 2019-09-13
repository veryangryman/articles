# Установка и настройка сервера OpenVPN #

- Устанавливаем пакеты openvpn и easy-rsa
- Копируем содержимое каталога `/usr/share/easy-rsa/` в каталог `/etc/openvpn`
```
cp -r /usr/share/easy-rsa/ /etc/openvpn
```
- Заполняем поля в вайле `vars` и сохраняем его в `/etc/openvpn/easy-rsa/vars`

```
set_var EASYRSA                 "$PWD"
set_var EASYRSA_PKI             "$EASYRSA/pki"
set_var EASYRSA_DN              "cn_only"
set_var EASYRSA_REQ_COUNTRY     "RU"
set_var EASYRSA_REQ_PROVINCE    "Tula region"
set_var EASYRSA_REQ_CITY        "Tula"
set_var EASYRSA_REQ_ORG         "NOORG CERTIFICATE AUTHORITY"
set_var EASYRSA_REQ_EMAIL       "littlesmilingcloud@gmail.com"
set_var EASYRSA_REQ_OU          "LITTLESMILINGCLOUD EASY CA"
set_var EASYRSA_KEY_SIZE        2048
set_var EASYRSA_ALGO            rsa
set_var EASYRSA_CA_EXPIRE       7500
set_var EASYRSA_CERT_EXPIRE     365
set_var EASYRSA_NS_SUPPORT      "no"
set_var EASYRSA_NS_COMMENT      "NOORG CERTIFICATE AUTHORITY"
set_var EASYRSA_EXT_DIR         "$EASYRSA/x509-types"
set_var EASYRSA_SSL_CONF        "$EASYRSA/openssl-1.0.cnf"
set_var EASYRSA_DIGEST          "sha256"
```

- Выполянем следующие команды для того, чтобы сгенерировать сертификаты для сервера (TODO оформить в скрипт):
```
cd /etc/openvpn/easy-rsa
./easyrsa init-pki
./easyrsa build-ca
./easyrsa gen-req noorg-server nopass
./easyrsa sign-req server noorg-server
./easyrsa gen-dh
./easyrsa gen-crl

openssl verify -CAfile pki/ca.crt pki/issued/noorg-server.crt

openvpn --genkey --secret ta.key

test -d /etc/openvpn/server/keys/ || mkdir /etc/openvpn/server/keys/
test -d /etc/openvpn/server/keys/noorg-server/ || mkdir /etc/openvpn/server/keys/noorg-server/



```

При этом пару раз спросит кодовую фразу для приватного сертификата.

- Теперь генерируем сертификаты для клиента:
```
CLIENT_CN="client01"
./easyrsa gen-req ${CLIENT_CN} nopass
./easyrsa sign-req client ${CLIENT_CN}

openssl verify -CAfile pki/ca.crt pki/issued/${CLIENT_CN}.crt

```

