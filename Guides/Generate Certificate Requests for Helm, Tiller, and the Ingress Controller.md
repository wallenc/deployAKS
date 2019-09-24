# Generate the certificates for Helm, Tiller, and the ingress controller
The steps below will guide you through the process of requesting certificates for Helm, Tiller, and the ingress controller from a Windows CA. These steps should be performed on a Windows server that is located in the same domain as your Certificate Authority.

There are two options for requesting and then exporting the certificates:
<ol>
<li>[Use Powershell](#Powershell)


# Powershell
In order to automate the certificate request, you'll need to copy [New-AKSCertificateRequest.ps1](https://github.com/wallenc/deployAKS/blob/master/Scripts/New-AKSCertificateRequest.ps1) to the Windows machine from where you'll be submitting the certificate requests.

Run the script with the following parameters
- webServerCertTemplateName - The name used for the web server certificate template
- certOutPath - The path to use for the certificate request and export
- applicationNameFQDN - The FQDN of your application

Example:

    New-AKSCertificateRequest.ps1 -webServerCertTemplateName webserver -certOutPath C:\Temp\Certs -applicationNameFQDN demo.azure.com

The resulting output directory will contain an .rsp, .req, .cer, and .pfx for Helm, Tiller, and your application fqdn. Additionally, the Trusted Root CA certificate will be exported and labeled rootCA.cer. You can safely delete all of the files except the .pfx and rootCA.cer.

## Manually generate certificate requests
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



