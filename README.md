# Create an AKS cluster with an HTTPS ingress-controller using only private IPs and certificates issued by an internal CA

An ingress controller is a piece of software that provides reverse proxy, configurable traffic routing, and TLS termination for Kubernetes services. Kubernetes ingress resources are used to configure the ingress rules and routes for individual Kubernetes services. Using an ingress controller and ingress rules, a single IP address can be used to route traffic to multiple services in a Kubernetes cluster.

This article shows you how to deploy the NGINX ingress controller in an Azure Kubernetes Service (AKS) cluster. The ingress controller is configured on an internal, private virtual network and IP address. No external access is allowed. Two applications are then run in the AKS cluster, each of which is accessible over the single IP address.

### At a high level this guide walks through the following

- Create a service principal with a limited scope
- Deploy AKS using an already existing VNET/subnet with no public IPs
- Secure Helm and Tiller with CA issued certificates
- Creating an internal load balancer
- Creating the ingress controller using private IPs and SSL termination- 
- Deploying a demo application
- Deploying an ingress route
- Configuring a remote system to trust the CA certificate chain
- Test the demo application using curl with cert verification

# Prerequisites
Azure CLI for Linux
https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-apt?view=azure-cli-latest

Helm
https://helm.sh/docs/using_helm/#installing-helm


# Create a service principal
An Azure service principal is an identity created for use with applications, hosted services, and automated tools to access Azure resources. This access is restricted by the roles assigned to the service principal, giving you control over which resources can be accessed and at which level. For security reasons, it's always recommended to use service principals with automated tools rather than allowing them to log in with a user identity.

In the example below, the scope of the service principal is limited to only the two resource groups to which it requires access. The first scope is for the resource group where the AKS cluster will be deployed. The second is for the resource group that contains the virtual network and subnet that will be used for the cluster resources:

    az ad sp create-for-rbac -n AKS_SP --role contributor \
        --scopes /subscriptions/061f5e92-edf2-4389-8357-a16f71a2cbf3/resourceGroups/AKS-DEMO-RG \
                /subscriptions/061f5e92-edf2-4389-8357-a16f71a2cbf3/resourceGroups/AKS-VNET-RG

You should see output similar to the following. <b>Make note of the appId and the password:</b>

    {
        "appId": "b2abba9c-ef9a-4a0e-8d8b-46d8b53d046b",
        "displayName": "AKS_SP",
        "name": "http://AKS_SP",
        "password": "2a30869c-388e-40cf-8f5f-8d99fea405bf",
        "tenant": "dbbbe410-bc70-4a57-9d46-f1a1ea293b48"
    }

# Create the cluster

The following steps walk through the process of creating the AKS cluster and configuring the required tools in order to access the cluster.

In the below examples, replace the parameters with values that suit your environment. Using the default settings for the network configuration creates a subnet with a /8 CIDR range. As this may be too large for your environment or overlap with an existing VNET, you can configure the cluster to use an already existing subnet. This example shows that configuration. If you would like to use the default settings, simply leave off the `--vnet-subnet-id parameter`. The Service Principal and Client Secret parameters should match the appId and password from the output of the sp create command above.

    az aks create --resource-group AKS-DEMO-RG --name demoAKSCluster --service-principal "ecca5e35-df9d-4c6a-b025-1f3035bf8213" --client-secret "dfd1c6e7-1660-4c2e-a4da-b5ba8b5b19a3" --vnet-subnet-id "/subscriptions/061f5e92-edf2-4389-8357-a16f71a2cbf3/resourceGroups/AKS-VNET-RG/providers/Microsoft.Network/virtualNetworks/AKS-DEMO-VNET/subnets/S-1" --generate-ssh-keys

When the above command completes, you should see output that resembles the following

    {
    "aadProfile": null,
    "addonProfiles": null,
    "agentPoolProfiles": [
        {
        "availabilityZones": null,
        "count": 3,
        "enableAutoScaling": null,
        "maxCount": null,
        "maxPods": 110,
        "minCount": null,
        "name": "nodepool1",
        "orchestratorVersion": "1.13.10",
        "osDiskSizeGb": 100,
        "osType": "Linux",
        "provisioningState": "Succeeded",
        "type": "AvailabilitySet",
        "vmSize": "Standard_DS2_v2",
        "vnetSubnetId": "/subscriptions/061f5e92-edf2-4389-8357-a16f71a2cbf3/resourceGroups/AKS-VNET-RG/providers/Microsoft.Network/virtualNetworks/AKS-DEMO-VNET/subnets/S-1"
        }
    ],
    "apiServerAuthorizedIpRanges": null,
    "dnsPrefix": "demoAKSClu-AKS-DEMO-RG-d8abb5",
    "enablePodSecurityPolicy": null,
    "enableRbac": true,
    "fqdn": "demoaksclu-aks-demo-rg-d8abb5-5951d80c.hcp.usgovvirginia.cx.aks.containerservice.azure.us",
    "id": "/subscriptions/061f5e92-edf2-4389-8357-a16f71a2cbf3/resourcegroups/AKS-DEMO-RG/providers/Microsoft.ContainerService/managedClusters/demoAKSCluster",
    "identity": null,
    "kubernetesVersion": "1.13.10",
    "linuxProfile": {
        "adminUsername": "azureuser",
        "ssh": {
        "publicKeys": [
            {
            "keyData": "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDOKhPxBD5P2du9GVLjV0f/79YjKncBHqSPa8vgFiUi9iE907/yI6iQdjEBe/DqT0KODhCZxEVjL15Gbe2vfu1jFHFg8MfYhh2heLAZbDp/20/Hc44a5rvVHKNygmgrwlLo6qyKunXAem2Uicv6tn3FGOiFbsSj15twgKuEvEiHr+V3wdjg0jtDh5WzUMQZZeK43ONJvBpdAgY1CahOM74XC9i/dwPIywy+8QjR2T/v6WghrmFWCMm6dIynRdvtiJ89GMe/1DtA+DBvXzP04r6uZy9wNFQFqQySVxDXnO52MDzh1FZtiBewbCG+xsJCb2iTNIPKa5ugjItJABHdFm6D azureadmin@ansibleubu1804\n"
            }
        ]
        }
    },
    "location": "usgovvirginia",
    "maxAgentPools": 1,
    "name": "demoAKSCluster",
    "networkProfile": {
        "dnsServiceIp": "10.0.0.10",
        "dockerBridgeCidr": "172.17.0.1/16",
        "loadBalancerSku": "Basic",
        "networkPlugin": "kubenet",
        "networkPolicy": null,
        "podCidr": "10.244.0.0/16",
        "serviceCidr": "10.0.0.0/16"
    },
    "nodeResourceGroup": "MC_AKS-DEMO-RG_demoAKSCluster_usgovvirginia",
    "provisioningState": "Succeeded",
    "resourceGroup": "AKS-DEMO-RG",
    "servicePrincipalProfile": {
        "clientId": "ecca5e35-df9d-4c6a-b025-1f3035bf8213",
        "secret": null
    },
    "tags": null,
    "type": "Microsoft.ContainerService/ManagedClusters",
    "windowsProfile": null
    }

## Install kubectl and get the credentials to connect to the cluster
  
    $ sudo az aks install-cli
    $ az aks get-credentials --resource-group AKS-DEMO-RG --name demoAKSCluster
    
    Merged "demoAKSCluster" as current context in /home/azureadmin/.kube/config

Make sure you're able to connect to the cluster.
  
    $ kubectl get nodes

The output should resemble the following:

| NAME                     | STATUS | ROLES | AGE | VERSION |
| ------------------------ | ------ | ----- | --- | ------- |
| aks-nodepool1-74185687-0 | Ready  | agent | 6m43s  | v1.12.8 |
| aks-nodepool1-74185687-1 | Ready  | agent | 6m52s  | v1.12.8 |
| aks-nodepool1-74185687-2 | Ready  | agent | 6m45s  | v1.12.8 |

## Install and configure Helm
Use the installation guide from [Helm](https://helm.sh/docs/using_helm/#installing-helm)   
>NOTE: You may need to add the path to the Helm binary to your PATH before you're able to use  Helm

    $ PATH="/usr/local/bin/helm:$PATH"

## Generate certificates for Helm, Tiller, and the ingress controller
Use this [guide](/guides/Generate Certificate Requests for Helm, Tiller, and the Ingress Controller.md) to generate the certificate requests and export with a private key

Once the certificates have been created, copy them to a directory on your Linux host.

## Convert the pfx files to .cer and .key files
The following steps will walk you through converting the PFX files to .crt and .key files so they are readable by Linux. 

You can either run these commands manually from the command line or convert the certificates using the bash script from my [GitHub](https://github.com/wallenc/deployAKS/blob/master/Scripts/convertCertificates.sh)

#### To manually convert the certificates run the below commands for each cert. Replace \<cert-name> with the name of the certificate to convert, and replace "PASSWORD" with the password used when exporting the certificate.
    
    openssl pkcs12 -clcerts -nokeys -in <cert-name>.pfx -out <cert-name>.crt" -password pass:PASSWORD -passin pass:PASSWORD

    openssl pkcs12 -nocerts -in <cert-name>.pfx -out <cert-name>.key -password pass:PASSWORD -passin pass:PASSWORD -passout pass:PASSWORD

    openssl rsa -in <cert-name>.key -out <cert-name>.nopass.key" -passin pass:PASSWORD

##### Convert the root certifcate to PEM format
    openssl x509 -inform der -in rootCA.cer -out rootCA.pem

#### Using a bash script to convert the certificates
See this [guide]()

### You should now have the following files:

\<ingress-cert-name>.crt  
\<ingress-cert-name>.key  
\<ingress-cert-name>.nopass.key

helm.crt  
helm.key  
helm.nopass.key

tiller.crt  
tiller.key
tiller.nopass.key


## Create a custom Tiller installation using TLS certificates

To create the Tiller installation we use the `helm init` command. In the below example we provide the TLS certificates that were generated in the previous section.

     helm init --tiller-tls --tiller-tls-cert ~/tiller.crt --tiller-tls-key ~/tiller.nopass.key --tiller-tls-verify --tls-ca-cert ~/rootCA.pem

### Add the Tiller service account and create the RBAC role

    $ kubectl create serviceaccount -n kube-system tiller

    $ kubectl create clusterrolebinding tiller-cluster-rule \
        --clusterrole=cluster-admin \
        --serviceaccount=kube-system:tiller

    $ kubectl patch deploy -n kube-system tiller-deploy \
        -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'

#### Reinitialize the service account

    helm init --service-account tiller --upgrade

#### Ensure the Tiller pod is ready with the `kubectl get pods` command

    kubectl get pods -n kube-system

You should now see the tiller pod in a running status

| NAME                           | READY | STATUS  | RESTARTS | AGE |
| ------------------------------ | ----- | ------- | -------- | --- |
| tiller-deploy-69775bbbc7-c42wp | 1/1   | Running | 0        | 5m  |

  
#### Configure TLS for the Helm client

Copy the Helm certificate and key to ~/.helm

    cp helm.crt ~/.helm/cert.pem
    cp helm.nopass.key ~/.helm/key.pem

Test the Helm connectivity to Tiller using the `--tls` flag
  
    $ helm version --tls

If TLS has been configured properly, you should see the following output
  
    Client: &version.Version{SemVer:"v2.10.0", GitCommit:"9ad53aac42165a5fadc6c87be0dea6b115f93090", GitTreeState:"clean"}
    Server: &version.Version{SemVer:"v2.10.0", GitCommit:"9ad53aac42165a5fadc6c87be0dea6b115f93090", GitTreeState:"clean"}

## Create the ingress controller

In this step, we'll deploy the ingress controller using an internal load balancer. This will not create any public endpoints and will only provide access to the ingress resource from the internal private network.

The first step is to create a manifest file which will be used for the load balancer resource. In the below example, I've created a file named internal-ingress.yml and assigned 10.240.0.42 as the loadBalancerIP. Be sure to provide a valid IP from the subnet where your AKS cluster is located. 

    controller:
      service:
        loadBalancerIP: 10.25.0.25
        annotations:
          service.beta.kubernetes.io/azure-load-balancer-internal: "true"

#### Create a namespace for the ingress controller

    $ kubectl create namespace ingress-demo
    namespace/ingress-demo created

#### Create a Kubernetes secret to add the certificate to the namespace

    $ kubectl create secret tls azure-demo-secret \
        -n ingress-demo \
        --key ~/demo.azure.com.nopass.key \
        --cert ~/demo.azure.com.crt
    secret/aks-ingress-tls created

Deploy the ingress controller

Now deploy the nginx-ingress chart with Helm. To use the manifest file created in the previous step, add the `-f internal-ingress.yaml` parameter. For added redundancy, two replicas of the NGINX ingress controllers are deployed with the `--set controller.replicaCount` parameter. To fully benefit from running replicas of the ingress controller, make sure there's more than one node in your AKS cluster.

The ingress controller also needs to be scheduled on a Linux node. Windows Server nodes (currently in preview in AKS) shouldn't run the ingress controller. A node selector is specified using the `--set nodeSelector` parameter to tell the Kubernetes scheduler to run the NGINX ingress controller on a Linux-based node. Also, the `--tls` parameter must be added as Helm/Tiller now uses TLS authentication.

> The following example creates a Kubernetes namespace for the ingress resources named ingress-demo. Specify a namespace for your own environment as needed. If your AKS cluster is not RBAC enabled, add `--set rbac.create=false` to the Helm commands.

> If you would like to enable client source IP preservation for requests to containers in your cluster, add `--set controller.service.externalTrafficPolicy=Local` to the Helm install command. The client source IP is stored in the request header under X-Forwarded-For. When using an ingress controller with client source IP preservation enabled, SSL pass-through will not work.

    $ helm install --name demo stable/nginx-ingress \
        --namespace ingress-demo \
        -f internal-ingress.yaml \
        --set controller.replicaCount=2 \
        --set controller.nodeSelector."beta\.kubernetes\.io/os"=linux \
        --set defaultBackend.nodeSelector."beta\.kubernetes\.io/os"=linux \
        --tls

Verify that the ingress services are running. I've added the ``--watch`` parameter to monitor the namespace for any changes as it may take a few minutes for the loadbalancer resource to initialize and acquire the external IP address.

    $ kubectl get svc -n ingress-demo --watch

| NAME                                        | TYPE         | CLUSTER-IP   | EXTERNAL-IP | PORT(S)                    | AGE   |
| ------------------------------------------- | ------------ | ------------ | ----------- | -------------------------- | ----- |
| demo-nginx-ingress-controller      | LoadBalancer | 10.0.158.131 | 10.240.0.42 | 80:31419/TCP,443:32441/TCP | 4m18s |
| demo-nginx-ingress-default-backend | ClusterIP    | 10.0.211.237 | \<none>     | 80/TCP                     | 4m18s |

## Add the demo application

Add the Azure-Samples repo to Helm and install the aks-helloworld application

    $ helm repo add azure-samples https://azure-samples.github.io/helm-charts/
    $ helm install azure-samples/aks-helloworld --namespace ingress-demo --tls

## Create an ingress route

The demo application is now running on your Kubernetes cluster. To route traffic to the application, create a Kubernetes ingress resource. The ingress resource configures the rules that route traffic to the applications.

In the following example, traffic to the address https://demo.azure.com is routed to the service named aks-helloworld.

Create a file named hello-world-ingress.yaml and copy in the following example YAML.

    apiVersion: extensions/v1beta1
    kind: Ingress
    metadata:
    name: hello-world-ingress
    namespace: ingress-demo
    annotations:
        kubernetes.io/ingress.class: nginx
        nginx.ingress.kubernetes.io/rewrite-target: /$1
    spec:
    tls:
    - hosts:
        - aks.demo.com
        secretName: aks-demo-secret
    rules:
    - host: aks.demo.com
        http:
        paths:
        - backend:
            serviceName: aks-helloworld
            servicePort: 80
            path: /(.*)
        - backend:
            serviceName: ingress-demo
            servicePort: 80
            path: /hello-world-two(/|$)(.*)

Create the ingress resource
  
    $ kubectl apply -f hello-world-ingress.yaml

## Add the CA certificate to the trusted store on the remote host

Either copy the demoArootCA.crt file to the VM or create a new .crt file and paste in the contents of rootCA.crt
Once you have the file created, add it to the trusted store:

    $ sudo cp rootCA.crt /etc/pki/ca-trust/source/anchors/
    $ sudo update-ca-trust

## Trust the CA certificate and test the demo application
The following steps are for Ubuntu. Please see the instructions for adding a new CA certificate for the Linux distro you're using. 

    $ sudo mkdir /usr/share/ca-certificates/extra

Modify /etc/ca-certificates.conf to include a reference to your new certificate.

    $ cat rootCert.crt >> /etc/ca-certificates.conf

Update CA certificates

    $ update-ca-certificates

If you don't have DNS configured to provide host name resolution for your application FQDN, add a host entry for demo.azure.com on the Linux host from where you'll be testing the application.

    $ sudo vim /etc/hosts

Add the following line

    10.240.0.42 demo.azure.com

Save and close the file

Test the application
curl -v https://demo.azure.com

### In the output, you should see the server certificate returned

    * About to connect() to demo.azure.com port 443 (#0)
    *   Trying 10.7.0.20...
    * Connected to demo.azure.com (10.7.0.20) port 443 (#0)
    * Initializing NSS with certpath: sql:/etc/pki/nssdb
    *   CAfile: /etc/pki/tls/certs/ca-bundle.crt
    CApath: none
    * SSL connection using TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
    * Server certificate:
    *       subject: O=aks-ingress-tls,CN=demo.azure.com
    *       start date: Aug 29 16:04:10 2019 GMT
    *       expire date: Aug 28 16:04:10 2020 GMT
    *       common name: demo.azure.com
    *       issuer: E=example@demo.azure.com,CN=demo.azure.com,O=Demo Azure,L=Charlotte,ST=NC,C=US

### If the connection was successful, you should see the following output

    <html xmlns="http://www.w3.org/1999/xhtml">
    <head>
        <link rel="stylesheet" type="text/css" href="/static/default.css">
        <title>Welcome to Azure Kubernetes Service (AKS)</title>

        <script language="JavaScript">
            function send(form){
            }
        </script>

    </head>
    <body>
        <div id="container">
            <form id="form" name="form" action="/"" method="post"><center>
            <div id="logo">Welcome to Azure Kubernetes Service (AKS)</div>
            <div id="space"></div>
            <img src="/static/acs.png" als="acs logo">
            <div id="form">
            </div>
        </div>
    </body>
    * Connection #0 to host demo.azure.com left intact
