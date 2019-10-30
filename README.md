# Create an AKS cluster with an HTTPS ingress-controller using only private IPs and certificates issued by a Windows CA

This article walks through the deployment of an NGINX ingress controller with SSL termination in an Azure Kubernetes Service (AKS) cluster. The ingress controller is configured on an internal, private virtual network with a private IP address, and will use a certificate issued by a Windows Certificate Authority. As an added security measure, both Helm and Tiller will be also be onfigured to use certificates. Once the ingress controller has been deployed, we'll then add a demo application and configure routing for the ingress resource.

### At a high level this guide walks through the following

- Creating a Service Principal
- Deploying an AKS cluster
- Installing and configuring Helm and Tiller
- Creating an internal load balancer
- Creating the ingress controller using private IPs and SSL termination
- Deploying a demo application
- Adding an ingress route for the application
- Configuring a remote system to trust the CA certificate chain
- Testing the demo application using curl with certificate validation

# Prerequisites
- [Azure CLI for Linux or Windows Subsystem for Linx](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-apt?view=azure-cli-latest)

# Create a service principal
If you wish to create a service principal with a limited scope, please see this [guide](). Otherwise, continue with the following instructions.

    $ az ad sp create-for-rbac -n AKS_SP

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

    az aks create --resource-group AKS-DEMO-RG --name demoAKSCluster --service-principal "b2abba9c-ef9a-4a0e-8d8b-46d8b53d046b" --client-secret "2a30869c-388e-40cf-8f5f-8d99fea405bf" --generate-ssh-keys

When the above command completes, you should see output that resembles the following

      {
      "aadProfile": null,
      "addonProfiles": null,
      "agentPoolProfiles": [
        {
          "availabilityZones": null,
          "count": 3,
          "enableAutoScaling": null,
          "enableNodePublicIp": null,
          "maxCount": null,
          "maxPods": 110,
          "minCount": null,
          "name": "nodepool1",
          "nodeTaints": null,
          "orchestratorVersion": "1.13.11",
          "osDiskSizeGb": 100,
          "osType": "Linux",
          "provisioningState": "Succeeded",
          "scaleSetEvictionPolicy": null,
          "scaleSetPriority": null,
          "type": "AvailabilitySet",
          "vmSize": "Standard_DS2_v2",
          "vnetSubnetId": null
        }
      ],
      "apiServerAccessProfile": null,
      "dnsPrefix": "demoAKSClu-AKS-DEMO-RG-d8abb5",
      "enablePodSecurityPolicy": null,
      "enableRbac": true,
      "fqdn": "demoaksclu-aks-demo-rg-d8abb5-31f98150.hcp.usgovvirginia.cx.aks.containerservice.azure.us",
      "id": "/subscriptions/d57e8588-4992-4af7-8580-ff38bf1e98bf/resourcegroups/AKS-DEMO-RG/providers/Microsoft.ContainerService/managedClusters/demoAKSCluster",
      "identity": null,
      "kubernetesVersion": "1.13.11",
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
        "loadBalancerProfile": {
          "effectiveOutboundIps": [
            {
              "id": "/subscriptions/d57e8588-4992-4af7-8580-ff38bf1e98bf/resourceGroups/MC_AKS-DEMO-RG_demoAKSCluster_usgovvirginia/providers/Microsoft.Network/publicIPAddresses/65a96698-8d88-4f94-bcc6-36d3200fa7fe",
              "resourceGroup": "MC_AKS-DEMO-RG_demoAKSCluster_usgovvirginia"
            }
          ],
          "managedOutboundIps": {
            "count": 1
          },
          "outboundIpPrefixes": null,
          "outboundIps": null
        },
        "loadBalancerSku": "Standard",
        "networkPlugin": "kubenet",
        "networkPolicy": null,
        "podCidr": "10.244.0.0/16",
        "serviceCidr": "10.0.0.0/16"
      },
      "nodeResourceGroup": "MC_AKS-DEMO-RG_demoAKSCluster_usgovvirginia",
      "provisioningState": "Succeeded",
      "resourceGroup": "AKS-DEMO-RG",
      "servicePrincipalProfile": {
        "clientId": "dc46c050-7f9e-4675-b1f4-9bb5ec9119b4",
        "secret": null
      },
      "tags": null,
      "type": "Microsoft.ContainerService/ManagedClusters",
      "windowsProfile": null
    }

## Install kubectl and get the credentials to connect to the cluster
  
    $ sudo az aks install-cli
    $ az aks get-credentials --resource-group AKS-DEMO-RG --name demoAKSCluster

> You should see the following output when the command completes    

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

>NOTE: You may need to add the path to the Helm binary to your PATH before you're able to use Helm

    $ PATH="/usr/local/bin/helm:$PATH"

    $ helm init --service-account tiller
    $ kubectl create serviceaccount --namespace kube-system tiller-sa
    $ kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller-sa

If you want to take an additional step and secure Helm and Tiller with TLS certificates, please see this [guide](https://github.com/wallenc/deployAKS/blob/master/Guides/Generate%20Certificate%20Requests%20for%20Helm%2C%20Tiller%2C%20and%20the%20Ingress%20Controller.md)

Now make sure the Tiller pod is up and running

    $ kubectl get pods -n kube-system

> You should now see the tiller pod in a running status

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

## Create the ingress controller

In this step, we'll deploy the ingress controller using an internal load balancer. This will not create any public endpoints and will only provide access to the ingress resource from the internal private network.

The first step is to create a manifest file which will be used for the load balancer resource. In the below example, I've created a file named internal-loadbalancer.yml and assigned 10.240.0.42 as the loadBalancerIP. Be sure to provide a valid IP from the subnet where your AKS cluster is located. 

    controller:
      service:
        loadBalancerIP: 10.240.0.42
        annotations:
          service.beta.kubernetes.io/azure-load-balancer-internal: "true"

#### Create a namespace for the ingress controller

    $ kubectl create namespace ingress-demo
    namespace/ingress-demo created

## Generate certificate the ingress controller
Use this [guide](https://github.com/wallenc/deployAKS/blob/master/Guides/Generate%20Certificate%20Requests%20for%20Helm%2C%20Tiller%2C%20and%20the%20Ingress%20Controller.md) to generate the certificate requests and export with a private key

Once the certificate has been created, copy it to a directory on your Linux host.

Convert the root certifcate to PEM format
    
    $ openssl x509 -inform der -in rootCA.cer -out rootCA.crt

#### Create a Kubernetes secret to add the certificate to the namespace

    $ kubectl create secret tls azure-demo-secret \
        -n ingress-demo \
        --key ~/demo.azure.com.nopass.key \
        --cert ~/demo.azure.com.crt
    secret/aks-ingress-tls created

## Deploy the ingress controller

Now deploy the nginx-ingress chart with Helm. To use the manifest file created in the previous step, we need to add the `-f internal-loadbalancer.yml` parameter. If this parameter isn't specified, the load balancer will be created with a public IP. For added redundancy, two replicas of the NGINX ingress controllers are deployed with the `--set controller.replicaCount` parameter. To fully benefit from running replicas of the ingress controller, make sure there's more than one node in your AKS cluster.

    $ helm install --name demo stable/nginx-ingress \
        --namespace ingress-demo \
        -f internal-loadbalancer.yml \
        --set controller.replicaCount=2

Verify that the ingress services are running. I've added the ``--watch`` parameter to monitor the namespace for any changes as it may take a few minutes for the loadbalancer resource to initialize and acquire the IP address specified in the internal-loadbalancer.yml manifest.

    $ kubectl get svc -n ingress-demo --watch

| NAME                                        | TYPE         | CLUSTER-IP   | EXTERNAL-IP | PORT(S)                    | AGE   |
| ------------------------------------------- | ------------ | ------------ | ----------- | -------------------------- | ----- |
| demo-nginx-ingress-controller      | LoadBalancer | 10.0.158.131 | 10.240.0.42 | 80:31419/TCP,443:32441/TCP | 4m18s |
| demo-nginx-ingress-default-backend | ClusterIP    | 10.0.211.237 | \<none>     | 80/TCP                     | 4m18s |

> If the EXTERNAL-IP remains in a pending status for more than 3-4 minutes, there could be an issue with allocating the IP address specified in the internal-loadbalancer.yml manifest. To check the status of the load balancer, run the following command.
``kubectl describe svc -n ingress-demo demo-nginx-ingress-controller``. If there is an issue with creating the loadbalancer, you will see the following status under Events:

    Events:
      Type     Reason                      Age   From                Message
      ----     ------                      ----  ----                -------
      Normal   EnsuringLoadBalancer        8s    service-controller  Ensuring load balancer
      Warning  CreatingLoadBalancerFailed  5s    service-controller  Error creating load balancer (will retry): failed to ensure load balancer for service ingress-demo/demo-nginx-ingress-controller: timed out waiting for the condition

>If you see the above message, double-check the internal-loadbalancer.yml manifest and ensure you've specified an IP that is in the CIDR range of the subnet to which your AKS cluster nodes are attached.

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

## Trust the CA certificate and test the demo application
The following steps are for Ubuntu. Please see the instructions for adding a new CA certificate for the Linux distro you're using. 

    $ sudo cp rootCA.crt /usr/share/ca-certificates/

Modify /etc/ca-certificates.conf to include a reference to your new certificate.

    $ sudo sed -i "\$arootCA.crt" /etc/ca-certificates.conf

Update CA certificates

    $ sudo update-ca-certificates

> You should see the following output

    Updating certificates in /etc/ssl/certs...
    1 added, 0 removed; done.
    Running hooks in /etc/ca-certificates/update.d...
    done.

If you don't have DNS configured to provide host name resolution for your application FQDN, add a host entry for demo.azure.com on the Linux host from where you'll be testing the application.

    $ sudo vim /etc/hosts

Add the following line

    10.240.0.42 demo.azure.com

Save and close the file

Test the application
    
    $ curl -v https://demo.azure.com

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
    
### References
[Create an HTTPS ingress controller and use your own TLS certificates on Azure Kubernetes Service (AKS)](https://docs.microsoft.com/en-us/azure/aks/ingress-own-tls)
[Create an ingress controller to an internal virtual network in Azure Kubernetes Service (AKS)](https://docs.microsoft.com/en-us/azure/aks/ingress-internal-ip)
