
#!/bin/bash

if [ $# -lt "1" ]
then
        printf "%s\n"
        printf "%s\n" "This script requires the following parameters"
        printf "%s\n" "---------------------------------------------------"
        printf "%s\n" "--cert-path:     The path to the pfx files to convert"
        printf "%s\n" "--root-cert:     The path and name of the root CA certificate"
        printf "%s\n" "--out-path:      The output path for the converted certs"
        printf "%s\n" "--pfx-password:  The password used to encrypt the private key"

        printf "%s\n\n" "------------------------------------------------"
        printf "%s\n" "EXAMPLE"
        printf "%s\n\n" "./convertCertificates.sh --cert-path ~/certs --root-cert ~/rootCertificate.cer  --out-path ~/certs/converted --pfx-password Password1"
        exit 1;
fi

while [[ $# -gt 0 ]]
do
value="$1"

case $value in
        --cert-path)
        certPath="$2"
        shift 2
        ;;
        --root-cert)
        rootCert="$2"
        shift 2
        ;;
        --out-path)
        outPath="$2"
        shift 2
        ;;
        --pfx-password)
        pfxPass="$2"
        shift 2
        ;;
        *)
        echo "Invalid argument $1"
        exit 1
        ;;
esac
done

if ! [ -d $certPath ]
then
        printf "%s\n" "--cert-path does not exist"
        exit 1
fi

if ! [ -d $outPath ]
then
        printf "%s\n" "--out-path does not exist. Creating directory"
        mkdir -p $outPath
        exit 1
fi

if [ -z "$pfxPass" ]
then
        printf "%s\n" "PFX password was not specified. Please rerun script and provide password to decrypt private key"
        exit 1
fi

for pfxfile in $certPath/*.pfx
do
        pfxName=$(basename -- $pfxfile)
        subjName=$(echo $pfxName | cut -f 1 -d '.')

        echo  $certName
        openssl pkcs12 -clcerts -nokeys -in $pfxfile -out "${outPath}/${subjName}.crt" -password pass:"${pfxPass}" -passin pass:"${pfxPass}"
        openssl pkcs12 -nocerts -in $pfxfile -out "${outPath}/${subjName}.key" -password pass:"${pfxPass}" -passin pass:"${pfxPass}" -passout pass:"${pfxPass}"
        openssl rsa -in "${outPath}/${subjName}.key" -out "${outPath}/${subjName}.nopass.key" -passin pass:"${pfxPass}"

        printf "%s\n\n" "Certificate and keyi files for ${subjName} were written to ${outPath}"

done

printf "%s\n" "Converting root certificate to PEM format"
openssl x509 -inform der -in $rootCert -out "${outPath}/rootCert.pem"

printf "%s\n" "Root certificate exported to ${outPath}"
