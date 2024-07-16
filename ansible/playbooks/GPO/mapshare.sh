# Import the Active Directory module
Import-Module ActiveDirectory

# Variables
$gpoName = "Map SharedFolder Drive"
$ouName = "DC=snaretraininglab,DC=local" # Update this to your specific OU within the domain
$driveLetter = "Z:"
$sharedFolderPath = "\\fs\SharedFolder"

# Create a new GPO
$gpo = New-GPO -Name $gpoName

# Link the GPO to the specified OU
New-GPLink -Name $gpoName -Target $ouName

# Get the GUID of the GPO
$gpoGUID = (Get-GPO -Name $gpoName).Id

# Path to the GPO User Configuration settings
$gpoPath = "\\\\snaretraininglab.local\\sysvol\\snaretraininglab.local\\Policies\\{$gpoGUID}\\User\\Preferences\\Drives\\Drives.xml"

# Create XML content for the mapped drive
$xmlContent = @"
<?xml version="1.0" encoding="UTF-8"?>
<DriveMaps clsid="{9351e504-0a34-4c74-8783-73a403c2a2e3}">
    <Drive clsid="{C08D3ECA-4B28-4C41-9444-EA95734C1B5C}" name="$driveLetter" status="P">
        <Properties action="U" thisDrive="TRUE" allDrives="FALSE">
            <DriveLetter>$driveLetter</DriveLetter>
            <Path>$sharedFolderPath</Path>
            <Label></Label>
            <Persistence>3</Persistence>
            <Hide>0</Hide>
            <Show>0</Show>
            <NoReconnect>0</NoReconnect>
            <UserContext>0</UserContext>
        </Properties>
    </Drive>
</DriveMaps>
"@

# Create the directory if it doesn't exist
$gpoDir = Split-Path -Path $gpoPath
if (-not (Test-Path -Path $gpoDir)) {
    New-Item -Path $gpoDir -ItemType Directory
}

# Write the XML content to the GPO path
Set-Content -Path $gpoPath -Value $xmlContent -Force

Write-Host "GPO '$gpoName' has been created and linked to '$ouName'. The shared folder '$sharedFolderPath' is mapped to drive letter '$driveLetter'."
