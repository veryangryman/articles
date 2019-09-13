#!/bin/dash

EXITCODE=0

ETCOPENVPN="/etc/openvpn"
ETCEASYRSA="/etc/openvpn/easy-rsa"
USREASYRSA="/usr/share/easy-rsa"
EASYRSAPKI="/etc/openvpn/easy-rsa/pki"


if [ -f "${OVPNTEMPLATE}" ]; then
    OVPNFILE=( )
    while IFS= read -r line; do
        OVPNFILE+=( "$line" )
    done < "${OVPNTEMPLATE}"
fi

[ -d "${ETCOPENVPN}" ] || { echo "${ETCOPENVPN} directory is missing"; exit 99; }
[ -d "${ETCEASYRSA}" ] || { echo "${ETCEASYRSA} directory is missing"; exit 99; }

[ -f "${ETCEASYRSA}/vars" ] || { echo "copy 'vars' file into ${ETCEASYRSA} directory!"; exit 99; }

cd "${ETCEASYRSA}" || { echo "cannot change current directory to ${ETCEASYRSA}"; exit 98; }

if [ $# -eq 1 ]; then
    SERVERNAME="noorg-server"
    CLIENTNAME="$1"
elif [ $# -eq 2 ]; then
    SERVERNAME="$1"
    CLIENTNAME="$2"
else
    echo "Usage: $0 [ <server-name> ] <client-name>"
    exit 97
fi

[ -f "${EASYRSAPKI}/private/ca.key" ] || { echo "Private key of CA is missing."; exit 96; }
[ -f "${EASYRSAPKI}/ca.crt" ] || { echo "Certificate of CA is missing"; exit 95; }


echo "creating of key of client ${CLIENTNAME}"
./easyrsa gen-req "${CLIENTNAME}" nopass
{ [ $? -eq 0 ] && echo "ok"; } || { echo "fail"; exit 1; }
./easyrsa sign-req client "${CLIENTNAME}"
{ [ $? -eq 0 ] && [ -f "${EASYRSAPKI}/issued/${CLIENTNAME}.crt" ] && echo "ok"; } || { echo "fail"; exit 1; }

echo "verify"
openssl verify -CAfile "${EASYRSAPKI}/ca.crt" "${EASYRSAPKI}/issued/${CLIENTNAME}.crt"
{ [ $? -eq 0 ] && echo "ok"; } || { echo "verification failed"; exit 2 ;}

echo "export to p12. don't forget setup the export password!"
mv ${EASYRSAPKI}/private/${CLIENTNAME}.key ${EASYRSAPKI}/private/${CLIENTNAME}__.key
openssl rsa -in ${EASYRSAPKI}/private/${CLIENTNAME}__.key -out ${EASYRSAPKI}/private/${CLIENTNAME}.key
./easyrsa export-p12 ${CLIENTNAME}
{ [ $? -eq 0 ] && [ -f ${EASYRSAPKI}/private/${CLIENTNAME}.p12 ] && echo "ok"; } || { echo "fail"; exit 3; }

echo "copy files"
FILESLIST="
${EASYRSAPKI}/ca.crt
${EASYRSAPKI}/issued/${CLIENTNAME}.crt
${EASYRSAPKI}/private/${CLIENTNAME}.key
"
[ -d "${ETCOPENVPN}/client" ] || mkdir -p "${ETCOPENVPN}/client"

for FILENAME in ${FILESLIST}
do
    echo "copy ${FILENAME}"
    cp "${FILENAME}" "${ETCOPENVPN}/client/"
done

if [ -n ]

exit ${EXITCODE}
