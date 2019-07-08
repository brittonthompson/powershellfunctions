function Invoke-KRestAPI {
    <#
    .SYNOPSIS
        Pulls data from the Kaseya Rest API
    .DESCRIPTION
        Authenticates and appends data as objects to an output object so you can get different types of data in one call.
    .EXAMPLE
        Invoke-KRestAPI -Credential $Cred -Agents -AgentsFilterMachineGroup "obe" -Software -Disks 
    .EXAMPLE
        Invoke-KRestAPI -Credential $Cred -AgentId 680240133782419 -Software -Disks
    .EXAMPLE
        Invoke-KRestAPI -Credential $Cred -Add -Orgs -Body $B
    .EXAMPLE
        Invoke-KRestAPI -Credential $Cred -Update -Orgs -Body $B
    .NOTES
        Documentation http://help.kaseya.com/webhelp/EN/RESTAPI/9050000/EN_restapiguide_R95.pdf
    #>
    
    [OutputType([PSCustomObject])]
    [CmdletBinding()]
    param(
        [string]$BaseUri, #https://<vsa address>/API/v1.0
        [PSCredential]$Credential,
        [switch]$TokenOnly,
        [switch]$Add,
        [switch]$Update,
        [string]$Body,
        [string]$Token,
        [string]$AgentId,
        [switch]$Agents,
        [string]$FilterMachineGroup,
        [string]$FilterCustom,
        [switch]$Software,
        [switch]$Disks,
        [switch]$Assets,
        [switch]$AssetTypes,
        [string]$AssetId,
        [switch]$Orgs,
        [string]$OrgRef,
        [string]$OrgId
    )

    $Output = New-Object PSObject

    #Establish a global token so we don't authenticate over and over
    if ($Token -and $Token -ne "") { $Global:Token = $Token } elseif ($Global:Token -and $Global:Token -ne "") { $Token = $Global:Token }

    #If there's no token authenticate
    if (-not $Token -or $Token -eq 0) {
        $Token = $Global:Token
        $Password = $Credential.GetNetworkCredential().Password
        $Username = $Credential.UserName
        $Random = Get-Random
        $RawSHA256Hash = Get-StringHash $Password
        $CoveredSHA256HashTemp = Get-StringHash "$Password$Username"
        $CoveredSHA256Hash = Get-StringHash "$CoveredSHA256HashTemp$Random"
        $RawSHA1Hash = Get-StringHash $Password -Algorithm SHA1
        $CoveredSHA1HashTemp = Get-StringHash "$Password$Username" -Algorithm SHA1
        $CoveredSHA1Hash = Get-StringHash "$CoveredSHA1HashTemp$Random" -Algorithm SHA1
        $Auth = "user=$Username,pass2=$CoveredSHA256Hash,pass1=$CoveredSHA1Hash,rpass2=$RawSHA256Hash,rpass1=$RawSHA1Hash,rand2=$Random,twofapass=:undefined"
        $AuthBase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($Auth))
        $Uri = "$BaseUri/auth"
        $Token = (Invoke-RestMethod -Method GET -Uri $Uri -Headers @{"Authorization" = "Basic $AuthBase64" }).Result.Token
        $Output | Add-Member -MemberType NoteProperty -Name Token -Value $Token
    }

    #Set the authentication headers and content type
    $Headers = @{"Authorization" = "Bearer $Token" }
    $ContentType = "application/json"

    #When adding items or updating we need to adjust the call and methods to include the body
    if ($Add -or $Update) { 
        if ($Add) { $Method = "POST" } else { $Method = "PUT" }
        $InvokeRestMethod = { (Invoke-RestMethod -Method $Method -Uri $Uri -ContentType $ContentType -Headers $Headers -Body $Body).Result }
    }
    else {
        $InvokeRestMethod = { (Invoke-RestMethod -Method GET -Uri $Uri -ContentType $ContentType -Headers $Headers).Result }
    }

    #TODO: Make these properties append instead of one at a time
    #Based on the desired data change the url and property name
    if ($Agents) { $Uri = "$BaseUri/assetmgmt/audit"; $PropertyName = "Agents" }
    if ($AgentId) { $Uri = "$BaseUri/assetmgmt/audit/$AgentId/summary"; $PropertyName = "Agents" }
    if ($Assets) { $Uri = "$BaseUri/assetmgmt/assets"; $PropertyName = "Assets" }
    if ($Agents -and $FilterMachineGroup) { $Uri += "?`$filter=endswith(GroupName,'$FilterMachineGroup')" }
    if ($Assets -and $FilterMachineGroup) { $Uri += "?`$filter=endswith(MachineGroup,'$FilterMachineGroup')" }
    if (($Agents -or $Assets) -and $FilterCustom) { $Uri += $FilterCustom }
    if ($AssetTypes) { $Uri = "$BaseUri/assetmgmt/assettypes"; $PropertyName = "AssetTypes" }
    if ($Orgs) { $Uri = "$BaseUri/system/orgs"; $PropertyName = "Orgs" }
    if ($OrgRef) { $Uri = "$BaseUri/system/orgs?`$filter=OrgRef eq '$OrgRef'"; $PropertyName = "Orgs" }
    if ($OrgId) { $Uri = "$BaseUri/system/orgs/$OrgId"; $PropertyName = "Orgs" }

    #Make the call for the given url
    if (-not $TokenOnly) {
        try {
            $Results = &$InvokeRestMethod 
            $AppendResults = @()
            foreach ($A in $Results) {
                if (-not $AgentID) { $AgentID = $A.AgentGuid }
                
                #Append the software objects
                if ($Software) {
                    $Uri = "$BaseUri/assetmgmt/audit/$($AgentId)/software/installedapplications"
                    $AgentSoftware = &$InvokeRestMethod
                    $A | Add-Member -MemberType NoteProperty -Name InstalledSoftware -Value (
                        $AgentSoftware | Where-Object {
                            $_.DirectoryPath -notmatch "^.*\\Windows\\.*" -and
                            $_.ProductName -notmatch "Microsoft.*Windows.*Operating.*System"
                        }
                    )
                }

                #Append the disk objects
                if ($Disks) {
                    $Uri = "$BaseUri/assetmgmt/audit/$($AgentId)/hardware/diskvolumes"
                    $AgentDisks = &$InvokeRestMethod
                    $A | Add-Member -MemberType NoteProperty -Name Disks -Value (
                        $AgentDisks | Where-Object {
                            $_.Type -ne "Removable" -and
                            $_.Type -ne "CDROM" 
                        }
                    )
                }

                #Add all current results to the array
                $AppendResults += $A
            }

            #Return the data or add the property
            if ($AppendResults) { $Return = $AppendResults } else { $Return = $Results }
            $Output | Add-Member -MemberType NoteProperty -Name $PropertyName -Value $Return
        }
        catch {
            Write-Host $_.Exception.Message -ForegroundColor Red
        }
    }
    $Output
}
