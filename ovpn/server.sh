#!/bin/dash

EXITCODE=0
ETCOPENVPN="/etc/openvpn"
ETCEASYRSA="${ETCOPENVPN}/easy-rsa"
USREASYRSA="/usr/share/easy-rsa"
EASYRSAPKI="${ETCEASYRSA}/pki"

[ -d "${ETCOPENVPN}" ] || { echo "${ETCOPENVPN} directory is missing"; exit 99; }

if [ ! -d "${ETCEASYRSA}" ]; then
    echo "trying to copy ${USREASYRSA} into ${ETCOPENVPN}"
    [ -d "${USREASYRSA}" ] || { echo "${USREASYRSA} is missing"; exit 99; }
    cp -r "${USREASYRSA}" "${ETCOPENVPN}" || { echo "copy easy-rsa to ${ETCOPENVPN} is failed"; exit 99; }
fi

[ -d "${ETCEASYRSA}" ] || { echo "${ETCEASYRSA} is still missing"; exit 99; }

[ -f "${ETCEASYRSA}/vars" ] || { [ -f "vars" ] && cp "vars" "${ETCEASYRSA}/vars"; }

[ -f "${ETCEASYRSA}/vars" ] || { echo "copy 'vars' file into ${ETCEASYRSA} directory!"; exit 99; }

cd "${ETCEASYRSA}" || { echo "cannot change current directory to ${ETCEASYRSA}"; exit 98; }

if [ $# -eq 0 ]; then
    SERVERNAME="noorg-server"
else
    SERVERNAME="$1"
fi

echo "initialization of Private Key Infrastructure {PKI} directory"
./easyrsa init-pki
{ [ $? -eq 0 ] && [ -d pki ] && echo "ok"; } || { echo "fail"; exit 1; }

echo "creation of Certificate Authority {CA}"
./easyrsa build-ca
{ [ $? -eq 0 ] && [ -f pki/ca.crt ] && [ -f pki/private/ca.key ] && echo "ok"; } || { echo "fail"; exit 2; }

echo "creation of a server key"
./easyrsa gen-req "${SERVERNAME}" nopass
{ [ $? -eq 0 ] && [ -f pki/private/${SERVERNAME}.key ] && echo "ok"; } || { echo "fail"; exit 3; }
./easyrsa sign-req server "${SERVERNAME}"
{ [ $? -eq 0 ] && [ -f pki/issued/${SERVERNAME}.crt ] && echo "ok"; } || { echo "fail"; exit 3; }

echo "verification of cerificates"
openssl verify -CAfile pki/ca.crt pki/issued/${SERVERNAME}.crt
{ [ $? -eq 0 ] && echo "ok"; } || { echo "fail"; exit 6; }

echo "generation of Diffie-Hellman parameters"
./easyrsa gen-dh
{ [ $? -eq 0 ] && [ -f pki/dh.pem ] && echo "ok"; } || { echo "fail"; exit 4; }
./easyrsa gen-crl
{ [ $? -eq 0 ] && [ -f pki/crl.pem ] && echo "ok"; } || { echo "fail"; exit 5; }

echo "creation of a server tls data"
openvpn --genkey --secret pki/ta.key
{ [ $? -eq 0 ] && [ -f pki/ta.key ] && echo "ok"; } || { echo "fail"; exit 7; }

echo "copy files"
FILESLIST="
${EASYRSAPKI}/ca.crt
${EASYRSAPKI}/issued/${SERVERNAME}.crt
${EASYRSAPKI}/private/${SERVERNAME}.key
${EASYRSAPKI}/dh.pem
${EASYRSAPKI}/crl.pem
${EASYRSAPKI}/ta.key
"

[ -d "${ETCOPENVPN}/server/keys" ] || mkdir -p "${ETCOPENVPN}/server/keys"

for FILENAME in ${FILESLIST}
do
    echo "copy ${FILENAME}"
    cp "${FILENAME}" "${ETCOPENVPN}/server/keys/"
done

exit 0
