function Invoke-KSoapAPI {
    <#
    .SYNOPSIS
        Pulls data from the Kaseya SOAP API
    .DESCRIPTION
        Authenticates and appends data as objects to an output object so you can get different types of data in one call.
    .EXAMPLE
        Invoke-KSoapAPI -Credential $Cred -OrgList -EventAlertList -EventSetList -AlarmList -Detailed -ReturnAllRecords
    .EXAMPLE
        Invoke-KSoapAPI -Credential $Cred -CloseAllAlarms -AlarmList -ReturnAllRecords
    .EXAMPLE
        Invoke-KSoapAPI -Credential $Cred -CloseAlarm ($Alarms.AlarmList | Where-Object{ $_.MonitorAlarmStateId -eq 1 }).MonitorAlarmID
    .NOTES
        Documentation http://help.kaseya.com/webhelp/EN/SOAPAPI/9030000/EN_soapapiguide_R93.pdf
    #>
    
    [OutputType([PSCustomObject])]
    [CmdletBinding()]
    param(
        [string]$BaseUri, #https://<vsa address>/vsaWS
        [PSCredential]$Credential,
        [switch]$AlarmList,
        [switch]$ReturnAllRecords,
        [switch]$Detailed,
        [switch]$EventAlertList,
        [switch]$EventSetList,
        [switch]$OrgList,
        [switch]$LogEntry,
        [string[]]$TransactionId,
        [string[]]$CloseAlarm,
        #CloseAllAlarms requires AlarmList and may require ReturnAllRecords
        [switch]$CloseAllAlarms,
        [string]$CloseAlarmMessage = $AckNote
    )
    
    #Create the output object
    $Output = New-Object PSObject

    #Create an executable variable to handle the dynamic addition of members to the object
    $AddToOutput = { 
        $Prop = ($Resp.PSObject.Properties | Where-Object { $_.TypeNameOfValue -notmatch "System" })[0].Name
        $Output | Add-Member -MemberType NoteProperty -Name $Prop -Value $Resp.$Prop
    }

    #Establish the SOAP proxy connection and get the dynamic namespace to prevent duplicate namespace errors
    $KaseyaWSUri = "$BaseUri/KaseyaWS.asmx?WSDL"
    $KaseyaWSProxy = New-WebServiceProxy -Uri $KaseyaWSUri
    $KaseyaWSProxy.Url = "$BaseUri/KaseyaWS.asmx"
    $KaseyWSNamespace = $KaseyaWSProxy.GetType().Namespace

    #Monitoring has a separate namespace so we need a different proxy for these calls
    if ($EventAlertList -or $EventSetList) {
        $MonitoringWSUri = "$BaseUri/MonitoringWS.asmx?WSDL"
        $MonitoringWSProxy = New-WebServiceProxy -Uri $MonitoringWSUri
        $MonitoringWSProxy.Url = "$BaseUri/MonitoringWS.asmx"
        $MonitoringWSNamespace = $MonitoringWSProxy.GetType().Namespace
    }
    
    #Authenticate if we do not have a session id established already
    if (-not $Global:SessionID -or $Global:SessionID -eq 0) {
        $Password = $Credential.GetNetworkCredential().Password
        $Username = $Credential.UserName
        $Random = Get-Random
        $CoveredSHA256HashTemp = Get-StringHash "$Password$Username"
        $CoveredSHA256Hash = Get-StringHash "$CoveredSHA256HashTemp$Random"
        $AuthenticationRequest = New-Object "$KaseyWSNamespace.AuthenticationRequest" -Property @{
            UserName         = $Username
            CoveredPassword  = $CoveredSHA256Hash
            RandomNumber     = $Random
            #BrowserIP = "10.1.6.103"
            HashingAlgorithm = "SHA-256"
        }
        
        $Resp = $KaseyaWSProxy.Authenticate($AuthenticationRequest)
        $Global:SessionID = $Resp.SessionID
        &$AddToOutput
    }
    
    #Each section below appends a new object if the parameters are true
    if ($OrgList) {
        $Obj = New-Object "$KaseyWSNamespace.GetOrgsRequest" -Property @{ SessionID = $Global:SessionID }
        $Resp = $KaseyaWSProxy.GetOrgs($Obj)
        &$AddToOutput
    }

    if ($EventAlertList) {
        $Obj = New-Object "$MonitoringWSNamespace.GetEventAlertListRequest" -Property @{ SessionID = $Global:SessionID; AgentGuid = $AgentGuid }
        $Resp = $MonitoringWSProxy.GetEventAlertList($Obj)
        &$AddToOutput
    }

    if ($EventSetList) {
        $Obj = New-Object "$MonitoringWSNamespace.GetEventSetListRequest" -Property @{ SessionID = $Global:SessionID; PartitionId = $PartitionID }
        $Resp = $MonitoringWSProxy.GetEventSetList($Obj)
        &$AddToOutput
    }

    if ($AlarmList) {
        $Obj = New-Object "$KaseyWSNamespace.GetAlarmListRequest" -Property @{ SessionID = $Global:SessionID; ReturnAllRecords = $ReturnAllRecords }
        $Resp = $KaseyaWSProxy.GetAlarmList($Obj)

        #Gather the details for each alarm and append it to an array. We use this as our Alarms object in output.
        if ($Detailed -and $Resp.Alarms) {
            $AllAlarms = @()
            $Resp.Alarms | ForEach-Object {
                $Obj = New-Object "$KaseyWSNamespace.GetAlarmRequest" -Property @{ SessionID = $Global:SessionID; MonitorAlarmID = $_.MonitorAlarmID }
                $Resp = $KaseyaWSProxy.GetAlarm($Obj)
                $AllAlarms += $Resp
            }

            $Output | Add-Member -MemberType NoteProperty -Name Alarms -Value $AllAlarms
        }
        else { &$AddToOutput }
    }

    if ($CloseAlarm -or $CloseAllAlarms) {
        #Collect all open alarms so we can close them
        if ($CloseAllAlarms) { $CloseAlarm = ($Output.Alarms | Where-Object { $_.MonitorAlarmStateId -eq 1 }).MonitorAlarmID }

        #Array to store the alarm closure repsonses
        $Closed = @()

        #Loop through all alarms and close them
        foreach ($C in $CloseAlarm) {
            $Obj = New-Object "$KaseyWSNamespace.CloseAlarmRequest" -Property @{ SessionID = $Global:SessionID; MonitorAlarmID = $C; Notes = $CloseAlarmMessage }
            $Resp = $KaseyaWSProxy.CloseAlarm($Obj)
            $Closed += $Resp        
        }
        $Output | Add-Member -MemberType NoteProperty -Name CloseAlarm -Value $Closed
    }

    if ($LogEntry) {
        $Logs = @()
        #Get a log entry for a specific transaction id
        if ($TransactionId) {
            foreach ($T in $TransactionId) {
                $Obj = New-Object "$KaseyWSNamespace.GetLogEntryRequest" -Property @{ SessionID = $Global:SessionID; TransactionId = $T }
                $Resp = $KaseyaWSProxy.GetLogEntry($Obj)
                $_logs += $Resp        
            }
            $Output | Add-Member -MemberType NoteProperty -Name LogEntry -Value $_logs
        }
        else {
            #Get the last log entry
            $Obj = New-Object "$KaseyWSNamespace.GetLogEntryRequest" -Property @{ SessionID = $Global:SessionID; TransactionId = $TransactionId }
            $Resp = $KaseyaWSProxy.GetLogEntry($Obj)
            &$AddToOutput
        }
    }

    #Return all collected data
    $Output
}
