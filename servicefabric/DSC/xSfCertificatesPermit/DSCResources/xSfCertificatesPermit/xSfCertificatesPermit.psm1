function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.UInt32]
        $DeploymentNodeIndex,

        [parameter(Mandatory = $true)]
        [System.String]
        $VMNodeTypePrefix,

        [parameter(Mandatory = $true)]
        [System.UInt32[]]
        $VMNodeTypeInstanceCounts,

        [Parameter(Mandatory = $false)]
        [System.String]
        $RootCACertBase64,

        [Parameter(Mandatory = $true)]
        [string] $AdminUserName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $ClusterCertificateCommonName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $ServerCertificateCommonName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $ReverseProxyCertificateCommonName,

        [parameter(Mandatory = $false)]
        [System.String[]]
        $AdditionalCertCommonNamesNeedNetworkAccess = @(),

        [parameter(Mandatory = $false)]
        [System.String]
        $ClusterCertificateThumbprint,

        [parameter(Mandatory = $false)]
        [System.String]
        $ServerCertificateThumbprint,

        [parameter(Mandatory = $false)]
        [System.String]
        $ReverseProxyCertificateThumbprint,

        [parameter(Mandatory = $true)]
        [System.Boolean]
        $StandaloneDeployment,
        
        [Parameter(Mandatory = $false)]
        [System.String]
        $ProviderIdentityApplicationId,
        
        [Parameter(Mandatory = $false)]
        [System.String]
        $ArmEndpoint,
        
        [Parameter(Mandatory = $false)]
        [System.String]
        $AzureKeyVaultDnsSuffix,
        
        [Parameter(Mandatory = $false)]
        [System.String]
        $AzureKeyVaultServiceEndpointResourceId,
        
        [Parameter(Mandatory = $false)]
        [System.String]
        $ProviderIdentityTenantId,
        
        [Parameter(Mandatory = $false)]
        [System.String]
        $ProviderIdentityCertCommonName,
        
        [Parameter(Mandatory = $false)]
        [System.String]
        $SubscriptionName,
        
        [Parameter(Mandatory = $false)]
        [System.String]
        $DSCAgentConfig
    )

    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    $VerbosePreference = [System.Management.Automation.ActionPreference]::Continue

    $returnValue = @{
        ClusterCert      = Get-ChildItem -Path cert:\LocalMachine\My | Where-Object -FilterScript { $PSItem.SubjectName.Name -eq "CN=$ClusterCertificateCommonName"; }
        ServerCert       = Get-ChildItem -Path cert:\LocalMachine\My | Where-Object -FilterScript { $PSItem.SubjectName.Name -eq "CN=$ServerCertificateCommonName"; }
        ReverseProxyCert = Get-ChildItem -Path cert:\LocalMachine\My | Where-Object -FilterScript { $PSItem.SubjectName.Name -eq "CN=$ReverseProxyCertificateCommonName"; }
    }

    return $returnValue
}

function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]
        [System.UInt32]
        $DeploymentNodeIndex,

        [parameter(Mandatory = $true)]
        [System.String]
        $VMNodeTypePrefix,

        [parameter(Mandatory = $true)]
        [System.UInt32[]]
        $VMNodeTypeInstanceCounts,

        [Parameter(Mandatory = $false)]
        [System.String]
        $RootCACertBase64,

        [Parameter(Mandatory = $true)]
        [string] $AdminUserName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $ClusterCertificateCommonName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $ServerCertificateCommonName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $ReverseProxyCertificateCommonName,

        [parameter(Mandatory = $false)]
        [System.String[]]
        $AdditionalCertCommonNamesNeedNetworkAccess = @(),

        [parameter(Mandatory = $false)]
        [System.String]
        $ClusterCertificateThumbprint,

        [parameter(Mandatory = $false)]
        [System.String]
        $ServerCertificateThumbprint,

        [parameter(Mandatory = $false)]
        [System.String]
        $ReverseProxyCertificateThumbprint,

        [parameter(Mandatory = $true)]
        [System.Boolean]
        $StandaloneDeployment,
        
        [Parameter(Mandatory = $false)]
        [System.String]
        $ProviderIdentityApplicationId,
        
        [Parameter(Mandatory = $false)]
        [System.String]
        $ArmEndpoint,
        
        [Parameter(Mandatory = $false)]
        [System.String]
        $AzureKeyVaultDnsSuffix,
        
        [Parameter(Mandatory = $false)]
        [System.String]
        $AzureKeyVaultServiceEndpointResourceId,
        
        [Parameter(Mandatory = $false)]
        [System.String]
        $ProviderIdentityTenantId,
        
        [Parameter(Mandatory = $false)]
        [System.String]
        $ProviderIdentityCertCommonName,
        
        [Parameter(Mandatory = $false)]
        [System.String]
        $SubscriptionName,
        
        [Parameter(Mandatory = $false)]
        [System.String]
        $DSCAgentConfig
    )

    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    $VerbosePreference = [System.Management.Automation.ActionPreference]::Continue
    
    Get-CommonModulePath | Import-Module -Verbose:$false

    $setTargetResourceInternalParam = @{
        DeploymentNodeIndex = $DeploymentNodeIndex
        VMNodeTypePrefix = $VMNodeTypePrefix
        VMNodeTypeInstanceCounts = $VMNodeTypeInstanceCounts
        RootCACertBase64 = $RootCACertBase64
        AdditionalCertCommonNamesNeedNetworkAccess = $AdditionalCertCommonNamesNeedNetworkAccess
        ClusterCertificateThumbprint = $ClusterCertificateThumbprint
        ServerCertificateThumbprint = $ServerCertificateThumbprint
        ReverseProxyCertificateThumbprint = $ReverseProxyCertificateThumbprint
    }

    $DSCResourceName = "xSfCertificatesPermit"

    if (-not $StandaloneDeployment) {

        $setTargetResourceInternalParam += @{
            ClusterCertificateCommonName = $ClusterCertificateCommonName
            ServerCertificateCommonName = $ServerCertificateCommonName
            ReverseProxyCertificateCommonName = $ReverseProxyCertificateCommonName
        }

        Set-TargetResourceInternalWrapper `
            -ProviderIdentityApplicationId $ProviderIdentityApplicationId `
            -ArmEndpoint $ArmEndpoint `
            -AzureKeyVaultDnsSuffix $AzureKeyVaultDnsSuffix `
            -AzureKeyVaultServiceEndpointResourceId $AzureKeyVaultServiceEndpointResourceId `
            -ProviderIdentityTenantId $ProviderIdentityTenantId `
            -ProviderIdentityCertCommonName $ProviderIdentityCertCommonName `
            -SubscriptionName $SubscriptionName `
            -DSCResourceName $DSCResourceName `
            -SetTargetResourceInternalParam $setTargetResourceInternalParam `
            -AdminUserName $AdminUserName `
            -DSCAgentConfig $DSCAgentConfig
     } else {

        $ClusterCertificateCommonName = Get-CertSubjectNameByThumbprint -Thumbprint $ClusterCertificateThumbprint
        $ServerCertificateCommonName = Get-CertSubjectNameByThumbprint -Thumbprint $ServerCertificateThumbprint

        if ( -not [string]::IsNullOrEmpty($ReverseProxyCertificateThumbprint))
        {
            $ReverseProxyCertificateCommonName = Get-CertSubjectNameByThumbprint -Thumbprint $ReverseProxyCertificateThumbprint
        }

        $setTargetResourceInternalParam += @{
            ClusterCertificateCommonName = $ClusterCertificateCommonName
            ServerCertificateCommonName = $ServerCertificateCommonName
            ReverseProxyCertificateCommonName = $ReverseProxyCertificateCommonName
        }

        Set-TargetResourceInternal @setTargetResourceInternalParam
     }
}

function Set-TargetResourceInternal
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]
        [System.UInt32]
        $DeploymentNodeIndex,

        [parameter(Mandatory = $true)]
        [System.String]
        $VMNodeTypePrefix,

        [parameter(Mandatory = $true)]
        [System.UInt32[]]
        $VMNodeTypeInstanceCounts,

        [Parameter(Mandatory = $false)]
        [System.String]
        $RootCACertBase64,

        [Parameter(Mandatory = $true)]
        [System.String]
        $ClusterCertificateCommonName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $ServerCertificateCommonName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $ReverseProxyCertificateCommonName,

        [parameter(Mandatory = $false)]
        [System.String[]]
        $AdditionalCertCommonNamesNeedNetworkAccess = @(),

        [parameter(Mandatory = $false)]
        [System.String]
        $ClusterCertificateThumbprint,

        [parameter(Mandatory = $false)]
        [System.String]
        $ServerCertificateThumbprint,

        [parameter(Mandatory = $false)]
        [System.String]
        $ReverseProxyCertificateThumbprint
    )

    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    $VerbosePreference = [System.Management.Automation.ActionPreference]::Continue

    Get-CommonModulePath | Import-Module -Verbose:$false

    # SF deployment workflow stage 1.1: Host Provision: Grant permissions to the installed certs
    #     Running on every node, preparing environment for service fabric installnation.

    # TODO: 
    #     1. Remove Import Root CA after RP/ARM cert pinning is finished. This is just a workaround solution.
    #     2. Remove hard-coded certificate CN when kv after the kv client is ready, read secret from url.
    
    # Import Root CA certificate
    if(-not [string]::IsNullOrEmpty($RootCACertBase64))
    {
        Write-Verbose "Importing Root CA Certificate..." -Verbose

        $rootCert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
        $rootCert.Import([System.Convert]::FromBase64String($RootCACertBase64))

        Write-Verbose "Root CA Certificate thumbprint: $($rootCert.Thumbprint)" -Verbose

        if (-not (dir Cert:\LocalMachine\Root | ? { $_.Thumbprint -eq $rootCert.Thumbprint })) {
            $store = New-Object System.Security.Cryptography.X509Certificates.X509Store @('Root', 'LocalMachine')
            $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]'ReadWrite')

            try {
                $store.Add($rootCert)
            }
            finally {
                $store.Close()
            }

            Write-Verbose "Root CA Certificate has been imported successfully" -Verbose
        }
        else {
            Write-Verbose "Root CA Certificate has been already imported" -Verbose
        }
    }

    # As per Service fabric documentation at:
    # https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-windows-cluster-x509-security#install-the-certificates
    # set the access control on this certificate so that the Service Fabric process, which runs under the Network Service account
    
    Write-Verbose "Granting Network access to SF Cluster Certificate" -Verbose
    Grant-CertAccess -SubjectName "CN=$ClusterCertificateCommonName" -ServiceAccount "Network Service"

    Write-Verbose "Granting Network access to SF Server Certificate" -Verbose
    Grant-CertAccess -SubjectName "CN=$ServerCertificateCommonName" -ServiceAccount "Network Service"

    Write-Verbose "Granting Network access to SF ReverseProxy Certificate" -Verbose
    Grant-CertAccess -SubjectName "CN=$ReverseProxyCertificateCommonName" -ServiceAccount "Network Service" -IsCertRequired $false

    foreach ($cn in $AdditionalCertCommonNamesNeedNetworkAccess)
    {
        Write-Verbose "Granting Network access to $cn Certificate" -Verbose
        Grant-CertAccess -SubjectName "CN=$cn" -ServiceAccount "Network Service"
    }

    # For first time deployment this will just pass through as the certs are already there and access have already been granted.
    # Refer: https://msftstack.wordpress.com/2016/05/12/extension-sequencing-in-azure-vm-scale-sets/

    if ([string]::IsNullOrEmpty($ClusterCertificateThumbprint))
    {
        $ClusterCertificateThumbprint = Get-CertLatestThumbPrintByCommonName -subjectName "CN=$ClusterCertificateCommonName"
    }

    if ([string]::IsNullOrEmpty($ServerCertificateThumbprint))
    {
        $ServerCertificateThumbprint = Get-CertLatestThumbPrintByCommonName -subjectName "CN=$ServerCertificateCommonName"
    }

    if ([string]::IsNullOrEmpty($ReverseProxyCertificateThumbprint))
    {
        $ReverseProxyCertificateThumbprint = Get-CertLatestThumbPrintByCommonName -subjectName "CN=$ReverseProxyCertificateCommonName"
    }

    $certificateThumbprints = @()
    $certificateThumbprints += $ClusterCertificateThumbprint
    $certificateThumbprints += $ServerCertificateThumbprint
    $certificateThumbprints += $ReverseProxyCertificateThumbprint
    foreach ($cn in $AdditionalCertCommonNamesNeedNetworkAccess)
    {
        $thumbprint = Get-CertLatestThumbPrintByCommonName -subjectName "CN=$cn"
        $certificateThumbprints += $thumbprint
    }

    # Check if current Node is master node.
    $isMasterNode = IsMasterNode -DeploymentNodeIndex $DeploymentNodeIndex -VMNodeTypePrefix $VMNodeTypePrefix -CurrentVMNodeTypeIndex $CurrentVMNodeTypeIndex

    if(-not $isMasterNode)
    {
        Write-Verbose "Certificate permissions setting is done on Node with index: '$CurrentVMNodeTypeIndex'. Synchronization only should happen on master node." -Verbose
        return
    }

    Wait-ForAllNodesReadiness -InstanceCounts $VMNodeTypeInstanceCounts `
        -VMNodeTypePrefix $VMNodeTypePrefix `
        -CertificateThumbprints $certificateThumbprints `
        -CertificateNeedNetworkServicePermissionThumbprints $certificateThumbprints `
        -TimeoutTimeInMin 10
}

function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.UInt32]
        $DeploymentNodeIndex,

        [parameter(Mandatory = $true)]
        [System.String]
        $VMNodeTypePrefix,

        [parameter(Mandatory = $true)]
        [System.UInt32[]]
        $VMNodeTypeInstanceCounts,

        [Parameter(Mandatory = $false)]
        [System.String]
        $RootCACertBase64,

        [Parameter(Mandatory = $true)]
        [string] $AdminUserName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $ClusterCertificateCommonName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $ServerCertificateCommonName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $ReverseProxyCertificateCommonName,

        [parameter(Mandatory = $false)]
        [System.String[]]
        $AdditionalCertCommonNamesNeedNetworkAccess = @(),

        [parameter(Mandatory = $false)]
        [System.String]
        $ClusterCertificateThumbprint,

        [parameter(Mandatory = $false)]
        [System.String]
        $ServerCertificateThumbprint,

        [parameter(Mandatory = $false)]
        [System.String]
        $ReverseProxyCertificateThumbprint,

        [parameter(Mandatory = $true)]
        [System.Boolean]
        $StandaloneDeployment,
        
        [Parameter(Mandatory = $false)]
        [System.String]
        $ProviderIdentityApplicationId,
        
        [Parameter(Mandatory = $false)]
        [System.String]
        $ArmEndpoint,
        
        [Parameter(Mandatory = $false)]
        [System.String]
        $AzureKeyVaultDnsSuffix,
        
        [Parameter(Mandatory = $false)]
        [System.String]
        $AzureKeyVaultServiceEndpointResourceId,
        
        [Parameter(Mandatory = $false)]
        [System.String]
        $ProviderIdentityTenantId,
        
        [Parameter(Mandatory = $false)]
        [System.String]
        $ProviderIdentityCertCommonName,
        
        [Parameter(Mandatory = $false)]
        [System.String]
        $SubscriptionName,
        
        [Parameter(Mandatory = $false)]
        [System.String]
        $DSCAgentConfig
    )

    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    $VerbosePreference = [System.Management.Automation.ActionPreference]::Continue

    Get-CommonModulePath | Import-Module -Verbose:$false

    if ([string]::IsNullOrEmpty($ClusterCertificateThumbprint))
    {
        $ClusterCertificateThumbprint = Get-CertLatestThumbPrintByCommonName -subjectName "CN=$ClusterCertificateCommonName"
    }

    if ([string]::IsNullOrEmpty($ServerCertificateThumbprint))
    {
        $ServerCertificateThumbprint = Get-CertLatestThumbPrintByCommonName -subjectName "CN=$ServerCertificateCommonName"
    }

    if ([string]::IsNullOrEmpty($ReverseProxyCertificateThumbprint))
    {
        $ReverseProxyCertificateThumbprint = Get-CertLatestThumbPrintByCommonName -subjectName "CN=$ReverseProxyCertificateCommonName"
    }

    $certificateThumbprints = @()
    $certificateThumbprints += $ClusterCertificateThumbprint
    $certificateThumbprints += $ServerCertificateThumbprint
    $certificateThumbprints += $ReverseProxyCertificateThumbprint
    foreach ($cn in $AdditionalCertCommonNamesNeedNetworkAccess)
    {
        $thumbprint = Get-CertLatestThumbPrintByCommonName -subjectName "CN=$cn"
        $certificateThumbprints += $thumbprint
    }

    # Removes null and empty item from arrays.
    $certificateThumbprintsWithoutEmpty = @($certificateThumbprints | Where-Object {-not [string]::IsNullOrEmpty($_)})
    $certificateNeedNetworkServicePermissionThumbprintsWithoutEmpty = @($certificateThumbprints | Where-Object {-not [string]::IsNullOrEmpty($_)})

    $isExpectedPermission = $true
    try
    {
        $certificateThumbprintsWithoutEmpty | % {
            $certThumbprint = $_
            $cert = dir Cert:\LocalMachine\My\ | ? {$_.Thumbprint -eq "$certThumbprint"}

            if(-not $cert)
            {
                throw "Can't find certificate with thumbprint $certThumbprint."
            }

            if (($certificateNeedNetworkServicePermissionThumbprintsWithoutEmpty).Contains($certThumbprint))
            {
                $rsaFile = $cert.PrivateKey.CspKeyContainerInfo.UniqueKeyContainerName
                $keyPath = "C:\ProgramData\Microsoft\Crypto\RSA\MachineKeys\"
                $fullPath = Join-Path $keyPath $rsaFile
                $acl = Get-Acl -Path $fullPath -ErrorAction SilentlyContinue
                $permission = ($acl.Access | ? {$_.IdentityReference -eq "NT AUTHORITY\NETWORK SERVICE"}).FileSystemRights
                $isExpectedPermission = $isExpectedPermission -and ($permission -eq "FullControl")
            }
        }
    }
    catch
    {
        $lastException = $_.Exception
        Write-Verbose "Waiting for all nodes readness failed because: $lastException." -Verbose
        return $false
    }

    return $isExpectedPermission
}

function Get-CommonModulePath
{
    $PSModulePath = $Env:PSModulePath -split ";" | Select-Object -Index 1
    $commonModulePath = "$PSModulePath\xSfClusterDSC.Common\xSfClusterDSC.Common.psm1"

    return $commonModulePath
}

Export-ModuleMember -Function *