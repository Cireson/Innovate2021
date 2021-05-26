<#
.SYNOPSIS
    Requestable Item Implementation

.DESCRIPTION
    This script will read the related Requuestable Item CI and grant the access

.INPUTS
    Set in the Params section

.OUTPUTS
    None

.NOTES
    Version:        1.0
    Author:         Geoff Ross (Cireson)
    Creation Date:  09/05/2021
    Purpose/Change: Inital Script.

#>

#-----------------------------------------------------------[Parameters]-----------------------------------------------------------

Param (
    [string]$ACGuid = $(throw 'You must include a runbook Workitem ID'),
    [string]$SCSMServer = $(throw 'You must include an SCSM management server')
)


#-------------------------------------------------------------[Settings]-----------------------------------------------------------

#Logging Settings
$LogFolder = "D:\Logs\Set-Approver-Dynamic"
$LogFileName = "Log"
$IsLogEnabled = $false
$IsDebugEnabled = $true

#---------------------------------------------------------[Initialisations]--------------------------------------------------------

#Set Error Action to Silently Continue 
$ErrorActionPreference = "Stop"

#Add required modules if not already loaded
If (!(Get-Module SMLets)) {
    Import-Module SMlets -Force -DisableNameChecking -ErrorAction Stop
}
#------------------------------------------------------------[Functions]-----------------------------------------------------------

#Function to write to Log File
Function Write-Log {
    Param (
        [ValidateSet('Error','Warn','Info')]$Level,
        $LogMessage
    )

    $CurrentTime = (Get-Date -Format G) # Date for logging

    If ($IsLogEnabled -or $Level -eq "Error") {
        "$CurrentTime`t$Level`t$LogMessage" | Out-File $LogFilePath -Append
    }
    If ($IsDebugEnabled) {
        "$CurrentTime`t$Level`t$LogMessage" | Out-Host
    }
}

#Function to get the top Parent WI of an activity
Function Get-ParentWI {
    Param (
        $Activity,
        $ComputerName
    )
    
    #SCSM Splat
    $SCSM = @{
        ComputerName = $ComputerName
    }
    
    #Get Parent of this Activity
    $WIContainsActivityRel = Get-SCSMRelationshipClass "System.WorkItemContainsActivity" @SCSM
    $ParentWI = (Get-SCSMRelationshipObject -ByTarget $Activity @SCSM | Where-Object {$_.RelationshipId -eq $WIContainsActivityRel.Id}).SourceObject
    
    If ($ParentWI -eq $null) {
        # We've reached the top - Return Original Actvity
        Return $Activity
    }
    Else {
        # Parent is not confrmed as the root, and thus, we will loop into another "Get-ParentWI" function.
        Get-ParentWI -Activity $ParentWI @SCSM
    }
}

#Function to get the  Affected User (eg requestor) of the WI passed to it.
Function Get-AffectedUser {
    Param (
        $WI,
        [string]$ComputerName
    )
    
    $SCSM = @{
        ComputerName = $ComputerName
    }

    #Get affected user relationship object
    $AffectedUserRel = Get-SCSMRelationshipClass -name 'System.WorkItemAffectedUser' @SCSM

    #Get related standard
    $AffectedUser = Get-SCSMRelatedObject -SMObject $WI -Relationship $AffectedUserRel @SCSM

    Return $AffectedUser
}

#Function to get the  Related Requestbale Items of the WI passed to it.
Function Get-RelatedRIs {
    Param (
        $WI,
        [string]$ComputerName
    )
    
    $SCSM = @{
        ComputerName = $ComputerName
    }

    #Get related CI relationship object
    $WIRelatesToCIRel = Get-SCSMRelationshipClass -name 'System.WorkItemRelatesToConfigItem' @SCSM

    #Get related standard
    $RelatedCIs = Get-SCSMRelatedObject -SMObject $WI -Relationship $WIRelatesToCIRel @SCSM

    Return $RelatedCIs
}

Function Add-UserAccessRel {
    Param (
        $RI,
        $User,
        [string]$ComputerName
    )
    
    $SCSM = @{
        ComputerName = $ComputerName
    }

    #Get affected user relationship object
    $RIGivenToUsersRel = Get-SCSMRelationshipClass -name 'Cireson.RequestableItemGivenToUsers' @SCSM

    #Set affected user
    New-SCSMRelationshipObject -Relationship $RIGivenToUsersRel -Source $RI -Target $User -Bulk @SCSM
}

#----------------------------------------------------------[Declarations]----------------------------------------------------------

#SCSM Splat
$SCSM = @{
    ComputerName = $SCSMServer
}

#Log File Path
$LogFilePath = "$LogFolder\$LogFileName-$(Get-Date -Format "yyyy-MM-dd hh-mm-ss").log"

#Rels
$WIContainsActivityRel = Get-SCSMRelationshipClass System.WorkItemContainsActivity @SCSM
$RIHasApproversRel = Get-SCSMRelationshipClass Cireson.RequestableItemHasApprovers$ @SCSM

#-----------------------------------------------------------[Execution]------------------------------------------------------------

#--------Data Gathering---------#

#Get the AC Object
$AC = Get-SCSMObject -Id $ACGuid @SCSM

#Get the parent SR
$SR = Get-SCSMObject -Id (Get-ParentWI -Activity $AC @SCSM).Id @SCSM

#Related Items
$AffectedUser = Get-AffectedUser -WI $SR @SCSM
$RequestableItem = Get-RelatedRIs -WI $SR @SCSM

#Get AD User
$ADUuser = Get-ADUser -Identity $AffectedUser.UserName

#Get AD Group
$ADGroup = Get-ADGroup -Identity $RequestableItem.AccessGroup

#----------Processing-----------#

Add-ADGroupMember -Identity $ADGroup -Members $ADUuser

#Add them to users with access
Add-UserAccessRel -RI $RequestableItem -User $AffectedUser @SCSM

#-------------------------------------------------------------[Close]--------------------------------------------------------------

Remove-Module SMlets