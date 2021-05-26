<#
.SYNOPSIS
    Requestable Item Approvals

.DESCRIPTION
    This script will read the related Requuestable Item CI and dynamicaly create RAs

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

#Functionn to clean JSON
Function Clean-Json {
    Param (
        [string]$InputJSON
    )
    
    $Result = ""
    Try {
        $Result = ConvertFrom-Json -InputObject $InputJSON
        return $Result
    }
    Catch {
    }

    $StringBuilder = New-Object -TypeName System.Text.StringBuilder($InputJSON.Length)    
    #We should escape it, since the user prolly entered in a quote in the RO answer, and our RO doesn't escape that. So use the built-in CSV functionality...

    #first, add a newline character after the first left curly bracket. This guarantees no CSV parsing issues.
    $FirstCurlyBracket = $InputJSON.IndexOf("{")
    $JSONString = "{" + "`r`n" + $InputJSON.Substring($FirstCurlyBracket + 1)

    $JSONStringCSV = $null
    $JSONStringCSV = ConvertFrom-CSV -InputObject $JSONString -Delimiter "," 
    
    
    If ($JSONStringCSV.length -eq 0 -or $JSONStringCSV.length -eq $null) {
        #the RO creator didn't include newline characters in their RO mappings. So deal with it.
        $JSONString = $JSONString.Replace("`",", "`",`r`n")
        $JSONStringCSV = ConvertFrom-CSV -InputObject $JSONString  -Delimiter "," 
    }

    If ($JSONStringCSV.length -eq 0 -or $JSONStringCSV.length -eq $null) {
        throw "unable to parse json string. Was this string mapped properly?"
    }

    $StringBuilder.AppendLine("{") | out-null

    For ($i = 0; $i -lt $JSONStringCSV.length; $i++) {
    
        [string]$ThisItem =  $JSONStringCSV[$i].'{'

        If ($ThisItem.IndexOf(":") -le 0) { 
            Continue
        }
        [string]$Key = $ThisItem.Substring(0, $ThisItem.IndexOf(":"))
        [string]$Value = $ThisItem.Substring($ThisItem.IndexOf(":")+1)

        
        $StringBuilder.Append("`"" + $Key + "`"") | out-null #column 1. The quotes were already removed.
        [string]$EscapedValue = $Value.trim()
        if ($EscapedValue.Length -gt 2) {
            if ($EscapedValue.StartsWith("`"")) {
                $EscapedValue = $EscapedValue.Substring(1)
            }
            if ($EscapedValue.EndsWith("`"")) {
                $EscapedValue = $EscapedValue.Substring(0, $EscapedValue.Length - 1)
            }

            #replace our quotes.
            $EscapedValue = $EscapedValue.Replace("`"", "\`"").Trim()
        }
        else{
            $EscapedValue = "" #Make it empty for now, since our final string will add quotes.
        }

        #continue constructing our JSON string.
        $StringBuilder.Append(" : " ) | out-null
        $StringBuilder.Append("`"" + $EscapedValue + "`"") | out-null
        $StringBuilder.AppendLine("," ) | out-null #Always add a comma. The last item will actually throw an exception if it has a comma, when we try to convert from json. So deal with it before that.
        
    }        
    $StringBuilder.Append("}" ) | out-null

    $FinalJsonString = $StringBuilder.ToString();
    
    #Remove the final comma.
    $LastComma = $FinalJsonString.LastIndexOf(",")
    $FinalJsonString = $FinalJsonString.Substring(0, $LastComma) + $FinalJsonString.Substring($LastComma+1)

    Return $FinalJsonString
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

Function Get-Manager {
    Param (
        $User,
        [string]$ComputerName
    )
    
    $SCSM = @{
        ComputerName = $ComputerName
    }

    #Get user manages user relationship
    $UserManagesUserRel = Get-SCSMRelationshipClass -name 'System.UserManagesUser' @SCSM
    $UserManagesUserRelId = $UserManagesUserRel.Id.Guid
    
    #Get related manager
    $Manager = (Get-SCSMRelationshipObject -ByTarget $User @SCSM | Where-Object {$_.RelationshipId -eq $UserManagesUserRelId}).SourceObject

    Return $Manager
}

Function Get-BUM {
    Param (
        $User,
        [string]$ComputerName
    )
    
    $SCSM = @{
        ComputerName = $ComputerName
    }

    Function Get-NextManager {
        Param (
            $User,
            [string]$ComputerName
        )

        $Manager = Get-Manager -User $User @SCSM
        $Manager = Get-SCSMObject -Id $Manager.Id @SCSM
        If ($Manager.EmployeeId -le 2) { #next manager is bum
            Return $Manager
        } Else {
            Get-NextManager -User $Manager @SCSM
        }

    }

    $User = Get-SCSMObject -Id $User.Id @SCSM

    If ($User.EmployeeId -le 2) { #User is themselves a bum
        $Manager = Get-Manager -User $User @SCSM
        Return $Manager
    } Else {
        $Manager = Get-Manager -User $User @SCSM
        $Manager = Get-SCSMObject -Id $Manager.Id @SCSM
        If ($Manager.EmployeeId -le 2) { #direct manager is director
            If ($LineManagerAlreadyApproved) {
                Return $null
            } Else {
                Return $Manager
            }
        } Else { #loop until we find a director
            $Director = Get-NextManager -User $Manager @SCSM
            Return $Director
        }
    }
    
    Return $null
}

Function Get-SupportGroupMembers {
    Param (
        [ValidateSet('IR','PR','SR','CR','MA')]$Type,
        $SupportGroupName,
        [string]$ComputerName
    )
    
    $SCSM = @{
        ComputerName = $ComputerName
    }

    $Enums = @{
        IR = "IncidentTierQueuesEnum"
        PR = "ProblemSupportGroupEnum"
        SR = "ServiceRequestSupportGroupEnum"
        CR = "ChangeRequestSupportGroupEnum"
        MA = "ManualActivitySupportGroupEnum"
    }

    $AllUsers = Get-SCSMClass Microsoft.AD.User$ @SCSM | Get-SCSMObject @SCSM

    $SupportGroupEnum = Get-SCSMEnumeration $Enums.$Type @SCSM | Get-SCSMChildEnumeration -Depth Recursive @SCSM | Where-Object {$_.DisplayName -like "*$($SupportGroupName)*"}
    $ADGroupId = (Get-SCSMClass Cireson.SupportGroupMapping$ @SCSM | Get-SCSMObject @SCSM | Where-Object {$_.SupportGroupId -eq $SupportGroupEnum.Id}).AdGroupId
    $SCSMGroup = Get-SCSMObject -Id $ADGroupId @SCSM
    $ADGroup = Get-ADGroup -Identity $SCSMGroup.SID
    $ADMembers = Get-ADGroupMember -Identity $ADGroup
    $SCSMMembers = @()
    ForEach ($ADMember in $ADMembers) {
        $SCSMMembers += $AllUsers | Where-Object {$_.SID -eq $ADMember.SID}
    }

    Return $SCSMMembers
}

Function Get-NextAvailableSequenceID {
    Param (
        $WI,
        [string]$ComputerName
    )
    
    $SCSM = @{
        ComputerName = $ComputerName
    }

    #Sleep for a moment, if I'm creating activities too fast, the first one doesn't register in time.
    Start-Sleep -Seconds 2

    #Get WI contains activity relationship
    $WIContainsActivityRel = Get-SCSMRelationshipClass -name 'System.WorkItemContainsActivity' @SCSM

    $Activities = Get-SCSMRelatedObject -SMObject $WI -Relationship $WIContainsActivityRel @SCSM

    #If activities already exist in the WI
    If (($Activities | Measure-Object).Count -ge 1) {
        #Sort activities, select the last one and increment it
        $Activities = $Activities | Sort-Object -Property sequenceID
        $LastActivity = $Activities | Select-Object -Last 1
        $SequenceID = $LastActivity.SequenceID + 1
    }
    Else {
        #No activities currently exist, set the first activity to ID 0
        $SequenceID = 0
    }
    Return $SequenceID
}

Function Create-RA {
    Param (
        $ParentWI,
        $LineManager,
        [string]$Title,
        [string]$Description,
        [string]$ComputerName
    )
    
    $SCSM = @{
        ComputerName = $ComputerName
    }
    
    [int32]$SequenceID = Get-NextAvailableSequenceID -WI $ParentWI @SCSM

    $Projection = @{
        __Class = "System.WorkItem.Activity.ReviewActivity";
        __Object = @{
            Title = $Title;
            Description = $Description;
            SequenceID = $SequenceID;
            Status = "Pending";
            LineManagerShouldReview = $LineManager;
            ApprovalCondition = "ApprovalEnum.Percentage"
            ApprovalPercentage = 100
            Id = "RA{0}";
        }
        ParentWorkItem = $ParentWI
    }
 
    $RA = New-SCSMObjectProjection -Type System.WorkItem.Activity.ReviewActivityProjection -Projection $Projection -PassThru @SCSM

    Return $RA.Object
}


Function Assign-ReviewerToRA {
    Param (
        $RA,
        $User,
        $Veto = $false,
        $MustVote = $false,
        [string]$ComputerName
    )
    
    $SCSM = @{
        ComputerName = $ComputerName
    }

    #Get the two relationships
    $ReviewerIsUserRel = Get-SCSMRelationshipClass -name 'System.ReviewerIsUser' @SCSM
    $RAHasReviewerRel = Get-SCSMRelationshipClass -name 'System.ReviewActivityHasReviewer' @SCSM

    #Define a projection for the Reviewer object

    $Projection = @{
        __CLASS = "System.WorkItem.Activity.ReviewActivity"
        __SEED = $RA
        Reviewer = @{
            __CLASS = "System.Reviewer"
            __OBJECT = @{
                ID="{0}"
                Veto = $Veto
                MustVote = $MustVote
            }
        } 
    } 

    #Create the reveiwers object and link it to the RA at the same time 

    New-SCSMObjectProjection -Type System.WorkItem.Activity.ReviewActivityViewProjection$ -Projection $Projection @SCSM
  
    #Get reviewer object just created
    $Reviewer = Get-SCSMRelatedObject -SMObject $RA -Relationship $RAHasReviewerRel @SCSM | Sort-Object -Property TimeAdded -Descending | Select-Object -First 1
    
    #Check if User is set
    If ($User -ne $null) {
        #Relate the User to the Reviewer
        New-SCSMRelationshipObject -Relationship $ReviewerIsUserRel -Source $Reviewer -Target $User -Bulk @SCSM
    } Else {
        Set-SCSMObject -SMObject $RA -Property Comments -Value "Failed to set approver"
    }
}

Function Set-AffectedUser {
    Param (
        $WI,
        $User,
        [string]$ComputerName
    )
    
    $SCSM = @{
        ComputerName = $ComputerName
    }

    #Get affected user relationship object
    $AffectedUserRel = Get-SCSMRelationshipClass -name 'System.WorkItemAffectedUser' @SCSM

    #Set affected user
    New-SCSMRelationshipObject -Relationship $AffectedUserRel -Source $WI -Target $User -Bulk @SCSM
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

#Get User Input
$UserInput = Clean-Json -InputJSON $SR.UserInputJSON
If ($UserInput.GetType().Name -eq "String") {
    $UserInput = ConvertFrom-Json -InputObject $UserInput
}

#Related Items
$AffectedUser = Get-AffectedUser -WI $SR @SCSM
$RequestableItem = Get-RelatedRIs -WI $SR @SCSM

#---------Execution------------#

#Description
$Description = "$($AffectedUser.FirstName) $($AffectedUser.LastName) has requested: $($RequestableItem.DisplayName) $($RequestableItem.Type.DisplayName)`n`nBusiness Case:`n$($UserInput.BusinessCase)"
Set-SCSMObject -SMObject $SR -Property Description -Value $Description @SCSM

# Approvals
$ApprovalSA = Get-SCSMRelatedObject -SMObject $SR -Relationship $WIContainsActivityRel @SCSM | Where-Object {$_.ClassName -eq "System.WorkItem.Activity.SequentialActivity" -and $_.Stage.DisplayName -eq "Approval"}

Switch ($RequestableItem.FirstApprover.DisplayName) {
    "Line Manager" {
        $Manager = Get-Manager -User $AffectedUser @SCSM
        $RA = Create-RA -ParentWI $ApprovalSA -LineManager $false -Title "Please review $($RequestableItem.DisplayName) $($RequestableItem.Type.DisplayName) request for $($AffectedUser.FirstName) $($AffectedUser.LastName)" -Description $($Description) @SCSM
        Assign-ReviewerToRA -RA $RA -User $Manager @SCSM
        Set-AffectedUser -WI $RA -User $AffectedUser @SCSM
    }
    "Business Unit Manager (BUM)" {
        $BUM = Get-BUM -User $AffectedUser @SCSM
        $RA = Create-RA -ParentWI $ApprovalSA -LineManager $false -Title "Please review $($RequestableItem.DisplayName) $($RequestableItem.Type.DisplayName) request for $($AffectedUser.FirstName) $($AffectedUser.LastName)" -Description $($Description) @SCSM
        Assign-ReviewerToRA -RA $RA -User $BUM @SCSM
        Set-AffectedUser -WI $RA -User $AffectedUser @SCSM
    }
}

Switch ($RequestableItem.SecondApprover.DisplayName) {
    "Line Manager" {
        $Manager = Get-Manager -User $AffectedUser @SCSM
        $RA = Create-RA -ParentWI $ApprovalSA -LineManager $false -Title "Please review $($RequestableItem.DisplayName) $($RequestableItem.Type.DisplayName) request for $($AffectedUser.FirstName) $($AffectedUser.LastName)" -Description $($Description) @SCSM
        Assign-ReviewerToRA -RA $RA -User $Manager @SCSM
        Set-AffectedUser -WI $RA -User $AffectedUser @SCSM
    }
    "Business Unit Manager (BUM)" {
        $BUM = Get-BUM -User $AffectedUser @SCSM
        $RA = Create-RA -ParentWI $ApprovalSA -LineManager $false -Title "Please review $($RequestableItem.DisplayName) $($RequestableItem.Type.DisplayName) request for $($AffectedUser.FirstName) $($AffectedUser.LastName)" -Description $($Description) @SCSM
        Assign-ReviewerToRA -RA $RA -User $BUM @SCSM
        Set-AffectedUser -WI $RA -User $AffectedUser @SCSM
    }
    "IT Procurement" {
        $RA = Create-RA -ParentWI $ApprovalSA -LineManager $false -Title "Please review $($RequestableItem.DisplayName) $($RequestableItem.Type.DisplayName) request for $($AffectedUser.FirstName) $($AffectedUser.LastName)" -Description $($Description) @SCSM
        $ITAdminUsers = Get-SupportGroupMembers -Type SR -SupportGroupName "IT Procurement" @SCSM
        ForEach ($ITAdminUser in $ITAdminUsers) {
            Assign-ReviewerToRA -RA $RA -User $ITAdminUser @SCSM
        }
        Set-SCSMObject -SMObject $RA -Property ApprovalPercentage -Value ([Math]::Floor(100/@($ITAdminUsers).Count)) @SCSM
        Set-AffectedUser -WI $RA -User $AffectedUser @SCSM
    }
    "Named Approvers" {
        $RA = Create-RA -ParentWI $ApprovalSA -LineManager $false -Title "Please review $($RequestableItem.DisplayName) $($RequestableItem.Type.DisplayName) request for $($AffectedUser.FirstName) $($AffectedUser.LastName)" -Description $($Description) @SCSM
        $Approvers = Get-SCSMRelationshipObject -BySource $RequestableItem @SCSM | Where-Object {$_.RelationshipId -eq $RIHasApproversRel.Id} | ForEach-Object {$_ | Select-Object -ExpandProperty TargetObject}
        ForEach ($Approver in $Approvers) {
            Assign-ReviewerToRA -RA $RA -User $Approver @SCSM
        }
        Set-SCSMObject -SMObject $RA -Property ApprovalPercentage -Value ([Math]::Floor(100/@($Approvers).Count)) @SCSM
        Set-AffectedUser -WI $RA -User $AffectedUser @SCSM
    }
}

#-----------Finish-------------#
    
Set-SCSMObject -SMObject $AC -Property Status -Value Completed @SCSM

#-------------------------------------------------------------[Close]--------------------------------------------------------------

Remove-Module SMlets