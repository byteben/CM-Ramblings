function Set-UpdateInDB {
    param
    (
        [parameter(Mandatory = $true)]
        [string]$ComputerName,
        [parameter(Mandatory = $true)]
        [string]$RBInstance,
        [ValidateSet("Insert", "Update")]
        [parameter(Mandatory = $true)]
        [string]$Action,
        [parameter(Mandatory = $true)]
        [string]$ArticleID,
        [parameter(Mandatory = $false)]
        [string]$AssignmentID,
        [parameter(Mandatory = $false)]
        [string]$ComplianceState,
        [parameter(Mandatory = $false)]
        [string]$EvaluationState,
        [parameter(Mandatory = $false)]
        [string]$LastAction,
        [parameter(Mandatory = $true)]
        [string]$SQLServer,
        [parameter(Mandatory = $true)]
        [string]$Database,
        [Parameter(Mandatory = $false)]
        [switch]$Component,
        [Parameter(Mandatory = $false)]
        [switch]$FileName,
        [Parameter(Mandatory = $false)]
        [switch]$Folder
    )
    if (!$LastAction) {
        #region status type hashtable
        $UpdateStatus = @{
            "23" = "WaitForOrchestration";
            "22" = "WaitPresModeOff";
            "21" = "WaitingRetry";
            "20" = "PendingUpdate";
            "19" = "PendingUserLogoff";
            "18" = "WaitUserReconnect";
            "17" = "WaitJobUserLogon";
            "16" = "WaitUserLogoff";
            "15" = "WaitUserLogon";
            "14" = "WaitServiceWindow";
            "13" = "Error";
            "12" = "InstallComplete";
            "11" = "Verifying";
            "10" = "WaitReboot";
            "9"  = "PendingHardReboot";
            "8"  = "PendingSoftReboot";
            "7"  = "Installing";
            "6"  = "WaitInstall";
            "5"  = "Downloading";
            "4"  = "PreDownload";
            "3"  = "Detecting";
            "2"  = "Submitted";
            "1"  = "Available";
            "0"  = "None";
        }
        #endregion status type hashtable
		
        $LastAction = $UpdateStatus.Get_Item($EvaluationState)
    }
    try {
        switch ($Action) {
            Insert {
                $InsertQuery = [string]::Format("INSERT INTO dbo.SoftwareUpdates VALUES ('{0}','{1}','{2}','{3}','{4}','{5}','{6}')", $ComputerName, $ArticleID, $AssignmentID, $ComplianceState, $Evaluationstate, $LastAction, $RBInstance)
                $startCompPatchQuerySplat = @{
                    Query     = $InsertQuery
                    SQLServer = $SQLServer
                    Log       = $true
                    Component = $ComputerName
                    $FileName = $FileName
                    $Folder   = $Folder
                    Database  = $Database
                }
                Start-CompPatchQuery @startCompPatchQuerySplat
            }
            Update {
                $Query = [System.Collections.ArrayList]::new()
                $Query.Add("UPDATE [dbo].[SoftwareUpdates] SET")
                $QuerySets = [System.Collections.ArrayList]::new()
                if ($ComplianceState) {
                    $QuerySets.Add([string]::Format("ComplianceState='{0}'", $ComplianceState))
                }
                if ($EvaluationState) {
                    $QuerySets.Add([string]::Format("EvaluationState='{0}'", $EvaluationState))
                }
                if ($LastAction) {
                    $QuerySets.Add([string]::Format("LastAction='{0}'", $LastAction))
                }
                $Query.Add($QuerySets -join ', ')
                $Query.Add([string]::Format("WHERE ServerName='{0}' AND RBInstance='{1}' AND ArticleID='{2}'", $ComputerName, $RBInstance, $ArticleID))
                [string]$Query = $Query -join ' '
                $getUpdateFromDBSplat = @{
                    ArticleID = $ArticleID
                    SQLServer = $SQLServer
                    Database  = $Database
                }
                $LastKnownStatus = Get-UpdateFromDB @getUpdateFromDBSplat
                if ($LastKnownStatus.ComplianceState -ne $ComplianceState -or $LastKnownStatus.EvaluationState -ne $EvaluationState -or $LastKnownStatus.LastAction -ne $LastAction) {
                    $startCompPatchQuerySplat = @{
                        Query     = $Query
                        SQLServer = $SQLServer
                        Log       = $true
                        Component = $ComputerName
                        $FileName = $FileName
                        $Folder   = $Folder    
                        Database  = $Database
                    }
                    Start-CompPatchQuery @startCompPatchQuerySplat
                }
            }
        }
        return $true
    }
    catch {
        $writeCMLogEntrySplat = @{
            Severity  = 3
            Value     = "Failed to $Action DB for $ArticleID"
            Component = $ComputerName
            $FileName = $FileName
            $Folder   = $Folder    
        }
        Write-CMLogEntry @writeCMLogEntrySplat 
        return $false
    }
}