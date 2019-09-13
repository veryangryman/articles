# Установка и настройка сервера OpenVPN

- Устанавливаем пакеты openvpn и easy-rsa
- Копируем содержимое каталога `/usr/share/easy-rsa/` в каталог `/etc/openvpn`
```
cp -r /usr/share/easy-rsa/ /etc/openvpn
```
- Заполняем поля в файле `vars` и сохраняем его в `/etc/openvpn/easy-rsa/vars`

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

## Ключи для сервера

Выполянем следующие команды для того, чтобы сгенерировать сертификаты для сервера (~~TODO: оформить в скрипт~~).

- Переходим в рабочую директорию
```
cd /etc/openvpn/easy-rsa
```

- Инициализируем директорию для PKI (Public Key Infrastructure). Если директория уже есть, то спросят подтверждение для её удаления.
```
./easyrsa init-pki
```

- Создаём ключ для Certificate Authority (CA, Удостоверяющий центр). При этом спросят кодовую фразу (pass phrase). Её надо ввести и запомнить, и не забывать. Иначе не сможете выписать новые сертификаты, а при замене надо будет обновлять уже выданные.
```
./easyrsa build-ca
```

- Создаётся ключ для сервера (`noorg-server`), а затем он заверяется (подписывается с помощью ключа Удостоверяющего сервера). Приватный ключ сервера сохраняется в директории `pki/private/noorg-server.key`.
 ```
./easyrsa gen-req noorg-server nopass
./easyrsa sign-req server noorg-server
 ```

- Так же генерируются параметры для алгоритма обмена открытыми ключами (Диффи-Хеллмана). Это занимает непривычно продолжительное время.
```
./easyrsa gen-dh
```
- Отозванные сертификаты хранятся в специальном файле (Certificate Revocation List, CRL). Для отзыва нужно использовать команду `./easyrsa revoke <name>`, а потом перегенерировать файл с информацией об отозванных ключах.
```
./easyrsa gen-crl
```
- Проверяем с помощью openssl, что всё нормально верифицируется.
```
openssl verify -CAfile pki/ca.crt pki/issued/noorg-server.crt
```
- Так же генерируем данные для TLS. Это называется Hash-based Message Authentication Code (HMAC).
```
openvpn --genkey --secret pki/ta.key
```

- Все команды одним списком.
```
cd /etc/openvpn/easy-rsa
./easyrsa init-pki
./easyrsa build-ca
./easyrsa gen-req noorg-server nopass
./easyrsa sign-req server noorg-server
./easyrsa gen-dh
./easyrsa gen-crl
openssl verify -CAfile pki/ca.crt pki/issued/noorg-server.crt
openvpn --genkey --secret pki/ta.key
```

При этом несколько раз спросит кодовую фразу для приватного сертификата, которым будут подписываться все остальные сертификаты.

- Накропал скрипт `server.sh`, который всё это делает. Порядок запуска:
```
server.sh [ <server-name> ]
```

- Теперь нужно разместить файлы в нужных местах.
```
cp pki/ca.crt                       /etc/openvpn/server/
cp pki/issued/noorg-server.crt      /etc/openvpn/server/
cp pki/private/noorg-server.key     /etc/openvpn/server/
cp pki/dh.pem                       /etc/openvpn/server/
cp pki/crl.pem                      /etc/openvpn/server/
cp pki/ta.key                       /etc/openvpn/server/

cp pki/ca.crt                       /etc/openvpn/client/
cp pki/issued/client01.crt          /etc/openvpn/client/
cp pki/private/client01.key         /etc/openvpn/client/
```


## Ключи для клиентов ВПН

Теперь генерируем сертификаты для клиента (TODO: оформить в скрипт). Тут уже гораздо проще, но принцип такой же.

- Генерируем сертификат для клиента с заданным именем (оно нам дальше понадобится)
```
./easyrsa gen-req ${CLIENTNAME} nopass
```
- Подписываем этот сертификат с помощью сертификата CA
```
./easyrsa sign-req client ${CLIENTNAME}
```

- Проверяем, что всё верифицируется.
```
openssl verify -CAfile pki/ca.crt pki/issued/${CLIENTNAME}.crt
```

- Перегоняем закрытый ключ клиента в формат RSA - это очень важный момент.
```
mv pki/private/${CLIENTNAME}.key pki/private/${CLIENTNAME}__.key
openssl rsa -in pki/private/${CLIENTNAME}__.key -out pki/private/${CLIENTNAME}.key
```

- Экспортируем сертификат в формате p12 (это тоже понадобится на некоторых устройствах). Желательно установить export password, а то на макось к этом очень привередлива. Полученный приватный ключ нужно передать на клиентское устройство неким безопасным способом.
```
./easyrsa export-p12 ${CLIENTNAME}
```

```
CLIENTNAME="client01"

./easyrsa gen-req ${CLIENTNAME} nopass
./easyrsa sign-req client ${CLIENTNAME}

openssl verify -CAfile pki/ca.crt pki/issued/${CLIENTNAME}.crt

mv pki/private/${CLIENTNAME}.key pki/private/${CLIENTNAME}__.key
openssl rsa -in pki/private/${CLIENTNAME}__.key -out pki/private/${CLIENTNAME}.key

./easyrsa export-p12 ${CLIENTNAME}
```

