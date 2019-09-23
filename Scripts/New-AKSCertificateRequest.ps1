<#
    .SYNOPSIS
        This script generates certificates for Helm, Tiller, and an ingress controller
        to be used for AKS

    .DESCRIPTION
        THe certificates generated from this script will use the Web Server and Computer
        templates issued by an Enterprise Certificate Authority. As those templates can
        have any name, they must be supplied to the script

    .PARAMETER webServerCertTemplateName
        The name of the template to use for the web server certificate that
        will be used for the ingress controller

    .PARAMETER computerCertTemplateName
        The name of the template to use for the computer certificates which
        will be used for TLS authentication between Helm and Tiller

    .PARAMETER certOutPath
        The desired path for the certificates

    .PARAMETER applicationNameFQDN
        Fully qualified name of the application, e.g. demo.azure.com.
        This will be used as the subject name for the certificate and must
        match the name of the application in Kubernetes

    .NOTES
        Version:        1.0
        Author:         Chris Wallen
        Creation Date:  9/20/2019

#>

Param
(
    [parameter(mandatory)]
    [string]
    $webServerCertTemplateName,

    [parameter(mandatory)]
    [string]
    $computerCertTemplateName,

    [parameter(mandatory)]
    [string]
    $certOutPath,

    [parameter(mandatory)]
    [string]
    $applicationNameFQDN
)

$pfxPassword = Read-Host -Prompt "Please enter a password the private key export" -AsSecureString
$verifyPassword = Read-Host -Prompt "Confirm the password for the private key" -AsSecureString

$pfxPassword_txt = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($pfxPassword))
$verifyPassword_txt = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($verifyPassword))

if ($pfxPassword_txt -ceq $verifyPassword_txt)
{

    $encryptedPwd = ConvertFrom-SecureString -SecureString $pfxPassword
    $secureString = ConvertTo-SecureString -String $encryptedPwd

    $subjectNameArray = 'helm', 'tiller', $applicationNameFQDN

    $pathExists = Get-Item -path $certOutPath -ErrorAction SilentlyContinue
    $caInfo = (certutil -dump)

    if (-not $pathExists)
    {
        Write-Output "Certificate output path does not exist. Creating directory $certOutPath"
        New-Item -Path $certOutPath -ItemType Directory
    }

    $caConfig = ($caInfo -match 'Config').Replace('Config:', '').Replace('`', '').Replace("'", '').Trim()

    $infTemplate = @'
[Version]
Signature="$Windows NT$"

[NewRequest]
Subject = "CN=[REPLACEME]"
Exportable = TRUE			; Make private key exportable
KeyLength = 4096			; Common key sizes: 512, 1024, 2048, 4096, 8192, 16384
KeySpec = 1                         	; AT_KEYEXCHANGE
KeyUsage = 0xA0                     	; Digital Signature, Key Encipherment
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
%szOID_SUBJECT_ALT_NAME2% = "{text}dns=[REPLACEME]"
%szOID_ENHANCED_KEY_USAGE% = "{text}%szOID_PKIX_KP_SERVER_AUTH%,%szOID_PKIX_KP_CLIENT_AUTH%"
'@

    foreach ($name in $subjectNameArray)
    {
        $certExists = Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object { $_.Subject -eq "CN=$name" }

        if ($certExists)
        {
            Write-Output "Cert $name exists in local machine personal store. Please delete before continuing"
        }
        else
        {
            $certName = $($name.Replace('.','').Replace('.',''))
            New-Item -Path "$certOutPath\$certName.inf" -Value $infTemplate.Replace('[REPLACEME]', $name) -Force | Out-Null
            certreq -new -f $certOutPath\$certName.inf "$certOutPath\$($certName).req" | Out-Null

            certreq -f -attrib "CertificateTemplate:$webServerCertTemplateName" -config $caConfig -submit "$certOutPath\$name.req" "$certOutPath\$name.cer" | Out-Null
            certreq -accept "$certOutPath\$certName.cer" -machine | Out-Null


            $certStorePath = Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object { $_.Subject -eq "CN=$name" }
            Export-PfxCertificate -Cert "Cert:\LocalMachine\My\$($certStorePath.Thumbprint)" -FilePath $certOutPath\$namcertName.pfx -Password $secureString | Out-Null
        }
    }
}
else
{
    Write-Error -Message "Passwords do not match. Please rerun script and try again"
}