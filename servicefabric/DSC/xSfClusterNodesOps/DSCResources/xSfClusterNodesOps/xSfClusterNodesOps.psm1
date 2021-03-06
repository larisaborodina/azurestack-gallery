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

        [parameter(Mandatory = $true)]
        [System.UInt32]
        $CurrentVMNodeTypeIndex,

        [parameter(Mandatory = $true)]
        [System.String]
        $ClientConnectionEndpointPort,

        [parameter(Mandatory = $true)]
        [System.String]
        $HTTPGatewayEndpointPort,

        [parameter(Mandatory = $true)]
        [System.String]
        $ReverseProxyEndpointPort,

        [parameter(Mandatory = $true)]
        [System.String]
        $EphemeralStartPort,

        [parameter(Mandatory = $true)]
        [System.String]
        $EphemeralEndPort,

        [parameter(Mandatory = $true)]
        [System.String]
        $ApplicationStartPort,

        [parameter(Mandatory = $true)]
        [System.String]
        $ApplicationEndPort,

        [parameter(Mandatory = $true)]
        [System.String]
        $ClientConnectionEndpoint,

        [Parameter(Mandatory = $true)]
        [System.String]
        $ClusterCertificateCommonName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $ServerCertificateCommonName,
 
        [Parameter(Mandatory = $false)]
        [System.String]
        $ClusterCertificateThumbprint,

        [Parameter(Mandatory = $false)]
        [System.String]
        $ServerCertificateThumbprint
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

    # NodeType name, Node name are required to use upper case to avoid case sensitive issues
    $VMNodeTypePrefix = $VMNodeTypePrefix.ToUpper()
    $vmNodeTypeName = "$VMNodeTypePrefix$CurrentVMNodeTypeIndex"

    $scaleSetDecimalIndex = ConvertFrom-Base36 -base36Num ($env:COMPUTERNAME.ToUpper().Substring(($vmNodeTypeName).Length))
    $nodeName = Get-NodeName -VMNodeTypeName $vmNodeTypeName -NodeIndex $scaleSetDecimalIndex

    $currentNode = $null

    # Define location of setup files on Temp disk.
    $setupDir = "E:\SFSetup"

    # Check if Cluster already exists on Master node.
    $clusterExists = ConnectClusterWithRetryAndExceptionSwallowed -SetupDir $setupDir `
        -ClientConnectionEndpoint $ClientConnectionEndpoint `
        -ServerCertificateThumbprint $ServerCertificateThumbprint `
        -ClusterCertificateThumbprint $ClusterCertificateThumbprint `
        -TimeoutTimeInMin 0 `
        -TimeoutBetweenProbsInSec 0

    if ($clusterExists)
    {
        Write-Verbose "Trying to get node $nodeName from Service Fabric cluster $ClientConnectionEndpoint" -Verbose

        # Work around error: Argument 'Connect-ServiceFabricCluster' is not recognized as a cmdlet: Unable to load DLL 'FabricCommon.dll': The specified module could not be found.
        # https://github.com/microsoft/service-fabric-issues/issues/794
        $env:Path += ";C:\Program Files\Microsoft Service Fabric\bin\fabric\Fabric.Code"

        Connect-ServiceFabricCluster -X509Credential `
                                -ConnectionEndpoint $ClientConnectionEndpoint `
                                -ServerCertThumbprint $ServerCertificateThumbprint `
                                -StoreLocation "LocalMachine" `
                                -StoreName "My" `
                                -FindValue $ClusterCertificateThumbprint `
                                -FindType FindByThumbprint `
                                -TimeoutSec 10

        $sfNodes = Get-ServiceFabricNode | % {$_.NodeName}
   
        if($sfNodes -contains $nodeName)
        {
            # If current node is already a part of the cluster, re-enable it if it is disabled, do nothing if it is enabled.
            Write-Verbose "Current node is a part of the cluster." -Verbose

            $currentNode = Get-ServiceFabricNode -NodeName $nodeName
        }
    }

    return $currentNode
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

        [parameter(Mandatory = $true)]
        [System.UInt32]
        $CurrentVMNodeTypeIndex,

        [parameter(Mandatory = $true)]
        [System.String]
        $ClientConnectionEndpointPort,

        [parameter(Mandatory = $true)]
        [System.String]
        $HTTPGatewayEndpointPort,

        [parameter(Mandatory = $true)]
        [System.String]
        $ReverseProxyEndpointPort,

        [parameter(Mandatory = $true)]
        [System.String]
        $EphemeralStartPort,

        [parameter(Mandatory = $true)]
        [System.String]
        $EphemeralEndPort,

        [parameter(Mandatory = $true)]
        [System.String]
        $ApplicationStartPort,

        [parameter(Mandatory = $true)]
        [System.String]
        $ApplicationEndPort,

        [parameter(Mandatory = $true)]
        [System.String]
        $ClientConnectionEndpoint,

        [Parameter(Mandatory = $true)]
        [System.String]
        $ClusterCertificateCommonName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $ServerCertificateCommonName,

        [parameter(Mandatory = $false)]
        [System.String]
        $ClusterCertificateThumbprint,

        [parameter(Mandatory = $false)]
        [System.String]
        $ServerCertificateThumbprint
    )

    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    $VerbosePreference = [System.Management.Automation.ActionPreference]::Continue

    Get-CommonModulePath | Import-Module -Verbose:$false

    # SF deployment workflow stage 2/2: Service Fabric Cluster Upgrade or Scale Out
    #        The installation happens on the first node of vmss ('master' node), scale out happens on newly added node.

    if ([string]::IsNullOrEmpty($ClusterCertificateThumbprint))
    {
        $ClusterCertificateThumbprint = Get-CertLatestThumbPrintByCommonName -subjectName "CN=$ClusterCertificateCommonName"
    }

    if ([string]::IsNullOrEmpty($ServerCertificateThumbprint))
    {
        $ServerCertificateThumbprint = Get-CertLatestThumbPrintByCommonName -subjectName "CN=$ServerCertificateCommonName"
    }

    # NodeType name, Node name are required to use upper case to avoid case sensitive issues
    $VMNodeTypePrefix = $VMNodeTypePrefix.ToUpper()
    $vmNodeTypeName = "$VMNodeTypePrefix$CurrentVMNodeTypeIndex"

    $scaleSetDecimalIndex = ConvertFrom-Base36 -base36Num ($env:COMPUTERNAME.ToUpper().Substring(($vmNodeTypeName).Length))
    $nodeName = Get-NodeName -VMNodeTypeName $vmNodeTypeName -NodeIndex $scaleSetDecimalIndex

    # Define location of setup files on Temp disk.
    $setupDir = "E:\SFSetup"
    cd $setupDir

    $ServiceFabricRunTimeDir = Join-Path $setupDir -ChildPath "SFRunTime"
    $fabricRuntimePackagePath = Get-ChildItem $ServiceFabricRunTimeDir -Filter *.cab -Recurse | % { $_.FullName }

    $addNode = $false

    # Check if Cluster already exists on Master node and if this is a addNode scenario.
    $clusterExists = ConnectClusterWithRetryAndExceptionSwallowed -SetupDir $setupDir `
        -ClientConnectionEndpoint $ClientConnectionEndpoint `
        -ServerCertificateThumbprint $ServerCertificateThumbprint `
        -ClusterCertificateThumbprint $ClusterCertificateThumbprint `
        -TimeoutTimeInMin 1 `
        -TimeoutBetweenProbsInSec 15

    if($clusterExists)
    {
        # If cluster already exists, check if current node already exists in cluster.
        Write-Verbose "Service Fabric cluster already exists. Checking if '$($nodeName)' already a member node." -Verbose

        # If Service Fabric already installed on the node we need to retry to make the node Up and Running after restart, otherwise just return current status
        $TimeoutTimeInMin = 0
        $TimeoutBetweenProbsInSec = 0
        if (IsServiceFabricInstalledOnNode)
        {
            $TimeoutTimeInMin = 5
            $TimeoutBetweenProbsInSec = 30
        }

        $isNodeUpAndRunning = IsNodeUpAndRunning -ClientConnectionEndpoint $ClientConnectionEndpoint `
           -ServerCertificateThumbprint $ServerCertificateThumbprint `
           -ClusterCertificateThumbprint $ClusterCertificateThumbprint `
           -NodeName $nodeName `
           -TimeoutTimeInMin $TimeoutTimeInMin `
           -TimeoutBetweenProbsInSec $TimeoutBetweenProbsInSec

        if($isNodeUpAndRunning)
        {
            # If current node is already a part of the cluster, re-enable it if it is disabled, do nothing if it is enabled.
            Write-Verbose "Current node is a part of the cluster and enabled, no action needed" -Verbose
            return
        } 
        else 
        {
            # clean up Service fabric installation on the node and add node back to cluster
            if (IsServiceFabricInstalledOnNode)
            {
                # the previous installation is still on the node, need to uninstall it first
                Write-Verbose "Current node is not in Up and Running state, cleanup the Service Fabric installation on the node." -Verbose
                Cleanup-ServiceFabricOnNode -NodeName $nodeName
            }
            else 
            {
                # it is OS upgrade scenario when previous installation is not on the node, but sf node folder is still on data disk
                Write-Verbose "Current node is not in Up and Running state, cleanup the folder" -Verbose
                Cleanup-ServiceFabricNodeFolder -NodeName $nodeName
            }

            $reJoin = $true
        }
            
        # If Cluster exists and current node is not part of the cluster then add the new node.
        Write-Verbose "Current node is not part of the cluster. Adding or re-joining node: '$nodeName'." -Verbose
        $addNode = $true
    }

    if($addNode)
    {
        # Prepare cluster configration to make sure new nodetype add before add new node
        Write-Verbose "Adding new or re-joining existed node, preparing cluster configration..." -Verbose
        Prepare-NodeType -setupDir $setupDir `
                            -VMNodeTypePrefix $VMNodeTypePrefix `
                            -CurrentVMNodeTypeIndex $CurrentVMNodeTypeIndex `
                            -ClusterCertificateThumbprint $ClusterCertificateThumbprint `
                            -ServerCertificateThumbprint $ServerCertificateThumbprint `
                            -ClientConnectionEndpointPort $ClientConnectionEndpointPort `
                            -HTTPGatewayEndpointPort $HTTPGatewayEndpointPort `
                            -ReverseProxyEndpointPort $ReverseProxyEndpointPort `
                            -EphemeralStartPort $EphemeralStartPort `
                            -EphemeralEndPort $EphemeralEndPort `
                            -ApplicationStartPort $ApplicationStartPort `
                            -ApplicationEndPort $ApplicationEndPort

        # Collect Node details
        Write-Verbose "Adding new node - Collect Node details" -Verbose
        $nodeIpAddressLable = (Get-NetIPAddress).IPv4Address | ? {$_ -ne "" -and $_ -ne "127.0.0.1"}
        $nodeIpAddress = [IPAddress](([String]$nodeIpAddressLable).Trim(' '))
        Write-Verbose "Node IPAddress: '$nodeIpAddress'" -Verbose

        $fdIndex = $scaleSetDecimalIndex
        $faultDomain = "fd:/$fdIndex"
        $upgradeDomain = "$scaleSetDecimalIndex"

        Write-Verbose "Adding new node - Start adding new node" -Verbose
        New-ServiceFabricNode -setupDir $setupDir `
                                -ServiceFabricUrl $ServiceFabricUrl `
                                -FabricRuntimePackagePath $fabricRuntimePackagePath `
                                -NodeName $nodeName `
                                -VMNodeTypeName $VMNodeTypeName `
                                -NodeIpAddress $nodeIpAddress `
                                -UpgradeDomain $upgradeDomain `
                                -FaultDomain $faultDomain `
                                -ClientConnectionEndpoint $ClientConnectionEndpoint `
                                -ServerCertificateThumbprint $ServerCertificateThumbprint `
                                -ClusterCertificateThumbprint $ClusterCertificateThumbprint
        
        # In rejoin case, directly return after adding node, no configuration setps are needed.		
        if($reJoin) 		
        {	
            Write-Verbose "Done rejoining node to cluster." -Verbose		
        }
        else
        {
            Write-Verbose "Successfully add new node." -Verbose
        }
    }
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

        [parameter(Mandatory = $true)]
        [System.UInt32]
        $CurrentVMNodeTypeIndex,

        [parameter(Mandatory = $true)]
        [System.String]
        $ClientConnectionEndpointPort,

        [parameter(Mandatory = $true)]
        [System.String]
        $HTTPGatewayEndpointPort,

        [parameter(Mandatory = $true)]
        [System.String]
        $ReverseProxyEndpointPort,

        [parameter(Mandatory = $true)]
        [System.String]
        $EphemeralStartPort,

        [parameter(Mandatory = $true)]
        [System.String]
        $EphemeralEndPort,

        [parameter(Mandatory = $true)]
        [System.String]
        $ApplicationStartPort,

        [parameter(Mandatory = $true)]
        [System.String]
        $ApplicationEndPort,

        [parameter(Mandatory = $true)]
        [System.String]
        $ClientConnectionEndpoint,

        [Parameter(Mandatory = $true)]
        [System.String]
        $ClusterCertificateCommonName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $ServerCertificateCommonName,

        [parameter(Mandatory = $false)]
        [System.String]
        $ClusterCertificateThumbprint,

        [parameter(Mandatory = $false)]
        [System.String]
        $ServerCertificateThumbprint
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

    # NodeType name, Node name are required to use upper case to avoid case sensitive issues
    $VMNodeTypePrefix = $VMNodeTypePrefix.ToUpper()
    $vmNodeTypeName = "$VMNodeTypePrefix$CurrentVMNodeTypeIndex"

    $scaleSetDecimalIndex = ConvertFrom-Base36 -base36Num ($env:COMPUTERNAME.ToUpper().Substring(($vmNodeTypeName).Length))
    $nodeName = Get-NodeName -VMNodeTypeName $vmNodeTypeName -NodeIndex $scaleSetDecimalIndex

    # Define location of setup files on Temp disk.
    $setupDir = "E:\SFSetup"

    # When "FABRIC_E_SERVER_AUTHENTICATION_FAILED" exception thrown, DSC should NOT start SF cluster self-healing logic.
    try
    {
        $clusterConnectable = ConnectClusterWithRetryAndExceptionThrown -SetupDir $setupDir `
            -ClientConnectionEndpoint $ClientConnectionEndpoint `
            -ServerCertificateThumbprint $ServerCertificateThumbprint `
            -ClusterCertificateThumbprint $ClusterCertificateThumbprint `
            -TimeoutTimeInMin 1 `
            -TimeoutBetweenProbsInSec 10 `
            | Out-Null
    }
    catch [System.Fabric.FabricServerAuthenticationFailedException]
    {
        $lastException = $_.Exception
        Write-Verbose "Connection false because $lastException. ErrorCode: $($lastException.ErrorCode). Message: $($lastException.Message)." -Verbose
        if ($lastException.ErrorCode -eq "ServerAuthenticationFailed") {
            Write-Verbose "ServerAuthenticationFailed indicates the cluster cannot be connected because of secret rotation failed. In this case, DSC should NOT trigger self-healing logic." -Verbose
            return $true
        }
    }
    catch
    {
        $lastException = $_.Exception
        Write-Verbose "Connection false because $lastException. The exception is swallowed." -Verbose
    }

    if ($clusterConnectable)
    {
        $isNodeUpAndRunning = IsNodeUpAndRunning -ClientConnectionEndpoint $ClientConnectionEndpoint `
                -ServerCertificateThumbprint $ServerCertificateThumbprint `
                -ClusterCertificateThumbprint $ClusterCertificateThumbprint `
                -NodeName $nodeName `
                -TimeoutTimeInMin 0 `
                -TimeoutBetweenProbsInSec 0

        return $isNodeUpAndRunning
    }

    return $false
}

# Provision util functions
function Prepare-NodeType
{
    param
    (
        [System.String] 
        $setupDir,

        [System.String] 
        $VMNodeTypePrefix,

        [System.String] 
        $CurrentVMNodeTypeIndex,

        [System.String] 
        $ClusterCertificateThumbprint,

        [System.String]
        $ServerCertificateThumbprint,

        [System.String]
        $ClientConnectionEndpointPort,

        [System.String]
        $HTTPGatewayEndpointPort,

        [System.String]
        $ReverseProxyEndpointPort,

        [System.String]
        $EphemeralStartPort,

        [System.String]
        $EphemeralEndPort,

        [System.String]
        $ApplicationStartPort,

        [System.String]
        $ApplicationEndPort
    )

    $ServiceFabricPowershellModulePath = Get-ServiceFabricPowershellModulePath -SetupDir $SetupDir
    Import-Module $ServiceFabricPowershellModulePath -ErrorAction SilentlyContinue -Verbose:$false

    # Work around error: Argument 'Connect-ServiceFabricCluster' is not recognized as a cmdlet: Unable to load DLL 'FabricCommon.dll': The specified module could not be found.
    # https://github.com/microsoft/service-fabric-issues/issues/794
    $env:Path += ";C:\Program Files\Microsoft Service Fabric\bin\fabric\Fabric.Code"

    Connect-ServiceFabricCluster -X509Credential `
                                 -ConnectionEndpoint $ClientConnectionEndpoint `
                                 -ServerCertThumbprint $ServerCertificateThumbprint `
                                 -StoreLocation "LocalMachine" `
                                 -StoreName "My" `
                                 -FindValue $ClusterCertificateThumbprint `
                                 -FindType FindByThumbprint `
                                 -TimeoutSec 10

    # Check node type existance
    Write-Verbose "Get current cluster configuration ..." -Verbose

    $clusterConfig = Get-ServiceFabricClusterConfiguration | ConvertFrom-Json
    $nodeTypeNames = $clusterConfig.Properties.NodeTypes | select -Property Name

    Write-Verbose "Current node types: $nodeTypeNames" -Verbose

    $VMNodeTypeName = "$VMNodeTypePrefix$CurrentVMNodeTypeIndex"
    if(-not ($nodeTypeNames -match $VMNodeTypeName))
    {
        # if current configuration don't have this nodetype, add a new node type
        Write-Verbose "Nodetype $VMNodeTypeName does not exist, updating cluster configuration..." -Verbose
        Write-Verbose "Generating new config file - Updating node type ..." -Verbose

        $nodeType = New-Object PSObject
        $nodeType | Add-Member -MemberType NoteProperty -Name "name" -Value "$VMNodeTypeName"
        $nodeType | Add-Member -MemberType NoteProperty -Name "clientConnectionEndpointPort" -Value "$ClientConnectionEndpointPort"
        $nodeType | Add-Member -MemberType NoteProperty -Name "clusterConnectionEndpointPort" -Value "19001"
        $nodeType | Add-Member -MemberType NoteProperty -Name "leaseDriverEndpointPort" -Value "19002"
        $nodeType | Add-Member -MemberType NoteProperty -Name "serviceConnectionEndpointPort" -Value "19003"
        $nodeType | Add-Member -MemberType NoteProperty -Name "httpGatewayEndpointPort" -Value "$HTTPGatewayEndpointPort"
        $nodeType | Add-Member -MemberType NoteProperty -Name "reverseProxyEndpointPort" -Value "$ReverseProxyEndpointPort"

        $applicationPorts = New-Object PSObject
        $applicationPorts | Add-Member -MemberType NoteProperty -Name "startPort" -Value "$ApplicationStartPort"
        $applicationPorts | Add-Member -MemberType NoteProperty -Name "endPort" -Value "$ApplicationEndPort"

        $ephemeralPorts = New-Object PSObject
        $ephemeralPorts | Add-Member -MemberType NoteProperty -Name "startPort" -Value "$EphemeralStartPort"
        $ephemeralPorts | Add-Member -MemberType NoteProperty -Name "endPort" -Value "$EphemeralEndPort"

        $nodeType | Add-Member -MemberType NoteProperty -Name "applicationPorts" -Value $applicationPorts
        $nodeType | Add-Member -MemberType NoteProperty -Name "ephemeralPorts" -Value $ephemeralPorts
        $nodeType | Add-Member -MemberType NoteProperty -Name "isPrimary" -Value $false

        $clusterConfig.properties.nodeTypes = $clusterConfig.properties.nodeTypes + $nodeType

        # For x509 remove windows Identity. (This is a issue in SF, should resolve this after new SF version comes)
        Write-Verbose "Generating new config file - Updating node type: Removing Windows Identity...(This step will be removed when new SF releases)" -Verbose
        $secObj = New-Object -TypeName PSCustomObject -Property @{'$id' = $clusterConfig.Properties.Security.'$id'; `
                                                                  CertificateInformation=$clusterConfig.Properties.Security.CertificateInformation; `
                                                                  ClusterCredentialType=$clusterConfig.Properties.Security.ClusterCredentialType; `
                                                                  ServerCredentialType=$clusterConfig.Properties.Security.ServerCredentialType}
        $clusterConfig.Properties.Security = $secObj

        # update version 
        $ver=[version]$clusterConfig.ClusterConfigurationVersion
        $newVer = "{0}.{1}.{2}" -f $ver.Major, $ver.Minor, ($ver.Build + 1)
        $clusterConfig.ClusterConfigurationVersion = $newVer
        Write-Verbose "Generating new config file - Updating node type: Updating config version from $ver to $newVer" -Verbose

        # out put to local file
        $updatedConfigFilePath = Join-Path -Path $setupDir -ChildPath "UpdatedConfig.json"
        $configContent = ConvertTo-Json $clusterConfig -Depth 99
        $configContent | Out-File $updatedConfigFilePath
        Write-Verbose "Generating new config file - Updating node type: Out put latest config file to $updatedConfigFilePath" -Verbose

        Write-Verbose "Start updating cluster configuration..." -Verbose
        Start-ServiceFabricClusterConfigurationUpgrade -ClusterConfigPath $updatedConfigFilePath

        Monitor-UpdateServiceFabricConfiguration
    }

    Write-Verbose "Cluster configration is ready for new nodetype." -Verbose
}

function New-ServiceFabricNode
{
    param
    (
        [System.String]
        $setupDir,

        [System.String]
        $ServiceFabricUrl,

        [System.String]
        $FabricRuntimePackagePath,

        [System.String]
        $NodeName,

        [System.String]
        $VMNodeTypeName,

        [System.String]
        $NodeIpAddress,

        [System.String]
        $ClientConnectionEndpoint,

        [System.String]
        $UpgradeDomain,

        [System.String]
        $FaultDomain,

        [System.String]
        $ServerCertificateThumbprint,

        [System.String]
        $ClusterCertificateThumbprint
    )

    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop

    # Adding the Node
    # Refer: https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-cluster-windows-server-add-remove-nodes
    Write-Verbose "Adding node '$NodeName' to Service fabric Cluster." -Verbose
    try {
        $output = .\ServiceFabric\AddNode.ps1 -NodeName $NodeName `
                                          -NodeType $VMNodeTypeName `
                                          -NodeIPAddressorFQDN $nodeIpAddress `
                                          -ExistingClientConnectionEndpoint $ClientConnectionEndpoint `
                                          -UpgradeDomain $UpgradeDomain `
                                          -FaultDomain $FaultDomain `
                                          -AcceptEULA `
                                          -ServerCertThumbprint $ServerCertificateThumbprint `
                                          -FindValueThumbprint $ClusterCertificateThumbprint `
                                          -StoreLocation "LocalMachine" `
                                          -StoreName "My" `
                                          -FabricRuntimePackagePath $FabricRuntimePackagePath `
                                          -X509Credential

    }
    catch {
        throw (($output | Out-String) + "`n Adding node '$NodeName' to Service fabric Cluster failed with error: $_.")
    }

    # Validate add
    Write-Verbose "Done with adding new node. Validating cluster to make sure new node exists" -Verbose

    # Work around error: Argument 'Connect-ServiceFabricCluster' is not recognized as a cmdlet: Unable to load DLL 'FabricCommon.dll': The specified module could not be found.
    # https://github.com/microsoft/service-fabric-issues/issues/794
    $env:Path += ";C:\Program Files\Microsoft Service Fabric\bin\fabric\Fabric.Code"
    
    $connection = Connect-ServiceFabricCluster -X509Credential `
                            -ConnectionEndpoint $ClientConnectionEndpoint `
                            -ServerCertThumbprint $ServerCertificateThumbprint `
                            -StoreLocation "LocalMachine" `
                            -StoreName "My" `
                            -FindValue $ClusterCertificateThumbprint `
                            -FindType FindByThumbprint `
                            -TimeoutSec 10 | Out-Null
                            

    Write-Verbose "Reconnect to Service Fabric cluster successfully : $connection" -Verbose

    $timeoutTime = (Get-Date).AddMinutes(5)
    $foundNode = $false

    while((-not $foundNode) -and ((Get-Date) -lt $timeoutTime))
    {
        $Error.Clear()
        $sfNodes = Get-ServiceFabricNode | % {$_.NodeName}

        $scaleSetDecimalIndex = ConvertFrom-Base36 -base36Num ($env:COMPUTERNAME.ToUpper().Substring(($vmNodeTypeName).Length))
        $nodeName = Get-NodeName -VMNodeTypeName $vmNodeTypeName -NodeIndex $scaleSetDecimalIndex

        if($sfNodes -contains $nodeName)
        {
            Write-Verbose "Node '$NodeName' succesfully added to the Service Fabric cluster." -Verbose
            $foundNode = $true
        }
        else
        {
            Write-Verbose "Service fabric node '$NodeName' is not found. Retrying until $timeoutTime." -Verbose
            Start-Sleep -Seconds 60
        }
    }

    if (-not $foundNode) 
    {
        throw "Service fabric node '$NodeName' could not be added. `n Please check the detailed DSC logs and Service fabric deployment traces at: '$setupDir\ServiceFabric\DeploymentTraces' on the VM: '$nodeName'."
    }
}

function Monitor-UpdateServiceFabricConfiguration
{
    # Wait 1 minutes to let the cluster start updating.
    Write-Verbose "Job submitted, waiting for 60 seconds before monitoring to let the upgrade task start..." -Verbose
    Start-Sleep -Seconds 60

    # Monitoring status. Reference: https://docs.microsoft.com/en-us/rest/api/servicefabric/sfclient-model-upgradestate
    Write-Verbose "Start monitoring cluster configration update..." -Verbose
    while ($true)
    {
        $udStatus = Get-ServiceFabricClusterUpgrade
        Write-Verbose "Current status $udStatus" -Verbose

        if($udStatus.UpgradeState -eq 'RollingForwardInProgress')
        {
            # Continue if it is RollingForwardInProgress
            Write-Verbose "Waiting for 60 seconds..." -Verbose
            Start-Sleep -Seconds 60
            continue
        }

        if($udStatus.UpgradeState -eq 'RollingForwardCompleted')
        {
            # Teminate monitoring if update complate.
            Write-Verbose "Cluster configration update completed" -Verbose
            break
        }

        # Other situations will be considered as failure
        Write-Verbose "Cluster configration update running into unexpected state!" -Verbose
        throw "Failed in updating Service Fabric cluster configuration."
    }
    Write-Verbose "Update cluster configration finished." -Verbose
}

function Cleanup-ServiceFabricOnNode
{
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $NodeName
    )

    try
    {
        Write-Verbose "Cleaning up Service Fabric runtime on the node '$NodeName'." -Verbose
        $output = .\ServiceFabric\CleanFabric.ps1 -KeepFabricData $true        
    }
    catch
    {
        Write-Verbose "Clean up Service Fabric installation on the '$NodeName' failed with error: $_." -Verbose
    }
}

function Cleanup-ServiceFabricNodeFolder
{
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $NodeName
    )

    try
    {
        Remove-Item -LiteralPath "E:\SF\$NodeName\" -Force -Recurse
    }
    catch
    {
        $ex = $_.Exception
        Write-Verbose "Cannot clean up Service Fabric node folder, message: $ex" -Verbose
    }
}

function Get-CommonModulePath
{
    $PSModulePath = $Env:PSModulePath -split ";" | Select-Object -Index 1
    $commonModulePath = "$PSModulePath\xSfClusterDSC.Common\xSfClusterDSC.Common.psm1"

    return $commonModulePath
}

Export-ModuleMember -Function *-TargetResource