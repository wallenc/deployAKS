# Generate the certificates for Helm, Tiller, and the ingress controller
The steps below will guide you through the process of requesting certificates for Helm, Tiller, and the ingress controller from a Windows CA. These steps should be performed on a Windows server that is located in the same domain as your Certificate Authority.

There are two options for requesting and then exporting the certificates:

- [Use Powershell to automate the process](#powershell)  
- [Manually performing the steps](#manual-cert-generation)

# Powershell
In order to automate the certificate request, you'll need to copy [New-AKSCertificateRequest.ps1](https://github.com/wallenc/deployAKS/blob/master/Scripts/New-AKSCertificateRequest.ps1) to the Windows machine from where you'll be submitting the requests.

Run the script with the following parameters
- webServerCertTemplateName - The name used for the web server certificate template
- certOutPath - The path to use for the certificate request and export
- applicationNameFQDN - The FQDN of your application

Example:

    New-AKSCertificateRequest.ps1 -webServerCertTemplateName webserver -certOutPath C:\Temp\Certs -applicationNameFQDN demo.azure.com

The resulting output directory will contain an .rsp, .req, .cer, and .pfx file for Helm, Tiller, and your application fqdn. Additionally, the Trusted Root CA certificate will be exported and labeled rootCA.cer. You can safely delete all of the files except the .pfx and rootCA.cer.

## Manual cert generation
Use this process if you prefer not to use Powershell to generate the requests as outlined in the previous section

#### Create an INF file that contains the information for the Tiller certificate
Copy the following text into a new file named tiller.inf

    [Version]
    Signature="$Windows NT$"

    [NewRequest]
    Subject = "CN=tiller"   ; Set the subject to helm with no fqdn
    ; For an empty subject use the following line instead or remove the Subject line entierely
    ; Subject =
    Exportable = TRUE			; Make sure the private key is exportable
    KeyLength = 4096			; Common key sizes: 512, 1024, 2048, 4096, 8192, 16384
    KeySpec = 1                         	; AT_KEYEXCHANGE
    KeyUsage = 0xA0                     	; Digital Signature, Key Encipherment
    MachineKeySet = TRUE
    ProviderName = "Microsoft RSA SChannel Cryptographic Provider"
    ProviderType = 12
    SMIME = FALSE
    RequestType = CMC

    ; At least certreq.exe shipping with Windows Vista/Server 2008 is required to interpret the [Strings] and [Extensions] sections below

    [Strings]
    szOID_SUBJECT_ALT_NAME2 = "2.5.29.17"
    szOID_ENHANCED_KEY_USAGE = "2.5.29.37"
    szOID_PKIX_KP_SERVER_AUTH = "1.3.6.1.5.5.7.3.1"
    szOID_PKIX_KP_CLIENT_AUTH = "1.3.6.1.5.5.7.3.2"

    [Extensions]
    %szOID_SUBJECT_ALT_NAME2% = "{text}dns=tiller"
    %szOID_ENHANCED_KEY_USAGE% = "{text}%szOID_PKIX_KP_SERVER_AUTH%,%szOID_PKIX_KP_CLIENT_AUTH%"

    
#### Create a certificate request from the INF file
Run the following commands from a command prompt. Make sure to replace ``webserver`` with the name of the web server certificate template issued by your CA. Also, replace the parameter ``-config`` with the value of the Config: section from ``certutil -dump``
    
    certreq -new tiller.inf tiller.req  
    
    certreq -f -attrib "CertificateTemplate:webserver" -config myCA.contoso.com\myCA-CA -submit tiller.req tiller.cer
    
    certreq -accept tiller.cer  

## Generate the certificate for Helm

#### Create an INF file that contains the information for the Helm certificate
Copy the following text into a new file named helm.inf

    [Version]
    Signature="$Windows NT$"

    [NewRequest]
    Subject = "CN=helm" ; Set the subject to helm with no fqdn
    Exportable = TRUE ; Make sure private key is exportable
    KeyLength = 4096 ; Common key sizes: 512, 1024, 2048, 4096, 8192, 16384
    KeySpec = 1 ; AT_KEYEXCHANGE
    KeyUsage = 0xA0 ; Digital Signature, Key Encipherment
    MachineKeySet = TRUE
    ProviderName = "Microsoft RSA SChannel Cryptographic Provider"
    ProviderType = 12
    SMIME = FALSE
    RequestType = CMC

    [Strings]
    szOID_SUBJECT_ALT_NAME2 = "2.5.29.17"
    szOID_ENHANCED_KEY_USAGE = "2.5.29.37"
    szOID_PKIX_KP_SERVER_AUTH = "1.3.6.1.5.5.7.3.1"
    szOID_PKIX_KP_CLIENT_AUTH = "1.3.6.1.5.5.7.3.2"

    [Extensions]
    %szOID_SUBJECT_ALT_NAME2% = "{text}dns=helm"
    %szOID_ENHANCED_KEY_USAGE% = "{text}%szOID_PKIX_KP_SERVER_AUTH%,%szOID_PKIX_KP_CLIENT_AUTH%"

#### Create a certificate request from the INF file
Use the same steps from the [Create a certificate request from the INF file](#Create-a-certificate-request-from-the-INF-file) section above, using the Helm certificates

## Create cert for ingress controller

Create an INF file that contains the information for the ingress controller certificate using the below text. Save the file as ingresscert.inf


    [Version]
    Signature="$Windows NT$"

    [NewRequest]
    Subject = "CN=demo.azure.com" ; Set the subject to demo.azure.com with no fqdn
    Exportable = TRUE ; Make sure private key is exportable
    KeyLength = 4096 ; Common key sizes: 512, 1024, 2048, 4096, 8192, 16384
    KeySpec = 1 ; AT_KEYEXCHANGE
    KeyUsage = 0xA0 ; Digital Signature, Key Encipherment
    MachineKeySet = TRUE
    ProviderName = "Microsoft RSA SChannel Cryptographic Provider"
    ProviderType = 12
    SMIME = FALSE
    RequestType = CMC

    [Strings]
    szOID_SUBJECT_ALT_NAME2 = "2.5.29.17"
    szOID_ENHANCED_KEY_USAGE = "2.5.29.37"
    szOID_PKIX_KP_SERVER_AUTH = "1.3.6.1.5.5.7.3.1"
    szOID_PKIX_KP_CLIENT_AUTH = "1.3.6.1.5.5.7.3.2"

    [Extensions]
    %szOID_SUBJECT_ALT_NAME2% = "{text}dns=demo.azure.com"
    %szOID_ENHANCED_KEY_USAGE% = "{text}%szOID_PKIX_KP_SERVER_AUTH%,%szOID_PKIX_KP_CLIENT_AUTH%"

#### Create a certificate request from the INF file
Use the same steps from the [Create a certificate request from the INF file](#Create-a-certificate-request-from-the-INF-file) section above, using the ingress controller certificate

### Export the certificates from the Computer personal store

<ol>
<li> Start -> Run -> MMC
<li> File -> Add/Remove Snap-In
<li> Certificates -> Add
<li> Computer Account -> Next -> Finish -> OK
<li> Expand certificates -> personal -> certificates
<li> Right click on tiller.contoso.com -> All tasks -> export
<li> Follow the wizard and make sure to export the private key
<li> Provide a password for the cert
<li> Save the cert with .pfx extension
</ol>

#### Follow the same steps as above for the Helm and demo application certificates

### Export the Trusted Root Certificate for your CA
<ol>
<li> Start -> Run -> MMC
<li> File -> Add/Remove Snap-In
<li> Certificates -> Add
<li> Computer Account -> Next -> Finish -> OK
<li> Expand certificates -> Trusted Root Certification Authorities -> Certificates
<li> Right on your Root CA certificate -> All tasks -> export
<li> Follow the wizard, making sure to export the certificate as "DER encoded binayr x.509"
<li> Save the certificate
</ol>

Once the certificates have been created, copy them to a directory on your Linux host.

## Convert the pfx files to .cer and .key files
The following steps will walk you through converting the PFX files to .crt and .key format which is required for Linux. You can either run these commands manually from the command line or convert the certificates using a bash script.

#### Using the bash script to convert the certificates
Copy [convertCertificates.sh](https://github.com/wallenc/deployAKS/blob/master/Scripts/convertCertificates.sh) to your Linux host. 

Mark the script as executable
    $ chmod u+x convertCertificates.sh

Run the script, using the following as an example. Make sure to replace the ``--cert-path``, ``--out-path``, and ``--pfx-password`` with values relevant to your scenario

    $ ./convertCertificates.sh --cert-path ~/certs --root-cert ~/rootCert.cer  --out-path ~/certs/converted --pfx-password PASSWORD

#### To manually convert the certificates run the below commands for each cert. Replace \<cert-name> with the name of the certificate to convert, and replace "PASSWORD" with the password used when exporting the certificate.
    
    $ openssl pkcs12 -clcerts -nokeys -in <cert-name>.pfx -out <cert-name>.crt" -password pass:PASSWORD -passin pass:PASSWORD

    $ openssl pkcs12 -nocerts -in <cert-name>.pfx -out <cert-name>.key -password pass:PASSWORD -passin pass:PASSWORD -passout pass:PASSWORD

    $ openssl rsa -in <cert-name>.key -out <cert-name>.nopass.key" -passin pass:PASSWORD

Convert the root certifcate to PEM format
    
    $ openssl x509 -inform der -in rootCA.cer -out rootCA.crt


### You should now have the following files:

- demoazurecom.crt
- demoazurecom.key
- demoazurecom.nopass.key

- helm.crt
- helm.key
- helm.nopass.key

- tiller.crt
- tiller.key
- tiller.nopass.key

- rootCA.crt

## Create a custom Tiller installation using TLS certificates

To create the Tiller installation we use the `helm init` command. In the below example we provide the TLS certificates that were generated in the previous section.

     $ helm init --tiller-tls --tiller-tls-cert ~/tiller.crt --tiller-tls-key ~/tiller.nopass.key --tiller-tls-verify --tls-ca-cert ~/rootCA.crt

### Add the Tiller service account and create the RBAC role

    $ kubectl create serviceaccount -n kube-system tiller

    $ kubectl create clusterrolebinding tiller-cluster-rule \
        --clusterrole=cluster-admin \
        --serviceaccount=kube-system:tiller

    $ kubectl patch deploy -n kube-system tiller-deploy \
        -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'

#### Reinitialize the service account

    $ helm init --service-account tiller --upgrade

#### Ensure the Tiller pod is ready with the `kubectl get pods` command

    $ kubectl get pods -n kube-system

You should now see the tiller pod in a running status

| NAME                           | READY | STATUS  | RESTARTS | AGE |
| ------------------------------ | ----- | ------- | -------- | --- |
| tiller-deploy-69775bbbc7-c42wp | 1/1   | Running | 0        | 5m  |

  
#### Configure TLS for the Helm client

Copy the Helm certificate and key to ~/.helm

    $ cp helm.crt ~/.helm/cert.pem
    $ cp helm.nopass.key ~/.helm/key.pem

Test the Helm connectivity to Tiller using the `--tls` flag
  
    $ helm version --tls

If TLS has been configured properly, you should see the following output
  
    Client: &version.Version{SemVer:"v2.10.0", GitCommit:"9ad53aac42165a5fadc6c87be0dea6b115f93090", GitTreeState:"clean"}
    Server: &version.Version{SemVer:"v2.10.0", GitCommit:"9ad53aac42165a5fadc6c87be0dea6b115f93090", GitTreeState:"clean"}
