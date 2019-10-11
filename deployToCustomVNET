# Deploy AKS to an already existing VNET/subnet

This article walks through the deployment of an NGINX ingress controller with SSL termination in an Azure Kubernetes Service (AKS) cluster. The ingress controller is configured on an internal, private virtual network with a private IP address, and will use a certificate issued by a Windows Certificate Authority. As an added security measure, both Helm and Tiller will be also be onfigured to use certificates. Once the ingress controller has been deployed, we'll then add a demo application and configure routing for the ingress resource.

### This guide walks through the following

- Creating a service principal with a limited scope
- Deploying AKS using an already existing VNET/subnet

## Prerequisites
[Azure CLI for Linux or Windows Subsystem for Linux](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest)

## Create a service principal
An Azure service principal is an identity created for use with applications, hosted services, and automated tools to access Azure resources. This access is restricted by the roles assigned to the service principal, giving you control over which resources can be accessed and at which level. For security reasons, it's always recommended to use service principals with automated tools rather than allowing them to log in with a user identity.

In the example below, the scope of the service principal is limited to only the two resource groups to which it requires access. The first scope is for the resource group where the AKS cluster will be deployed. The second is for the resource group that contains the virtual network and subnet that will be used for the cluster resources:

    $ az ad sp create-for-rbac -n AKS_SP --role contributor \
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

## Create the cluster

The following steps walk through the process of creating the AKS cluster and configuring the required tools in order to access the cluster.

In the below examples, replace the parameters with values that suit your environment. Using the default settings for the network configuration creates a subnet with a /8 CIDR range. As this may be too large for your environment or overlap with an existing VNET, you can configure the cluster to use an already existing subnet. This example shows that configuration. If you would like to use the default settings, simply leave off the `--vnet-subnet-id parameter`. The Service Principal and Client Secret parameters should match the appId and password from the output of the sp create command above.

    az aks create --resource-group AKS-DEMO-RG --name demoAKSCluster --service-principal "b2abba9c-ef9a-4a0e-8d8b-46d8b53d046b" --client-secret "2a30869c-388e-40cf-8f5f-8d99fea405bf" --vnet-subnet-id "/subscriptions/061f5e92-edf2-4389-8357-a16f71a2cbf3/resourceGroups/AKS-VNET-RG/providers/Microsoft.Network/virtualNetworks/AKS-DEMO-VNET/subnets/S-1" --generate-ssh-keys

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

You should see the following output

    Merged "demoAKSCluster" as current context in /home/azureadmin/.kube/config

Make sure you're able to connect to the cluster.
  
    $ kubectl get nodes

The output should resemble the following:

| NAME                     | STATUS | ROLES | AGE | VERSION |
| ------------------------ | ------ | ----- | --- | ------- |
| aks-nodepool1-74185687-0 | Ready  | agent | 6m43s  | v1.12.8 |
| aks-nodepool1-74185687-1 | Ready  | agent | 6m52s  | v1.12.8 |
| aks-nodepool1-74185687-2 | Ready  | agent | 6m45s  | v1.12.8 |
