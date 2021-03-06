# Initialize.
Import-Module -Name (Join-Path $PSScriptRoot 'Pwt.Drive.Helper.psm1') @ImportParams
$DriveRootPath = $Config['Tools']['Drive']['DriveRootPath'] = $Config['Tools']['Drive']['DriveRootPath'] | Get-PwtRootedPath
if (!(Test-Path -Path $DriveRootPath)) {
    $null = New-Item -ItemType Directory $DriveRootPath
}

$ExplorerConfirmModal = New-PodeWebModal -Name 'Delete Item' -Id 'DriveDeleteConfirm' -AsForm -Content @(
    New-PodeWebAlert -Type Warning -Id 'DriveDeleteConfirmAlert' -Value '[Placeholder]'
) -ScriptBlock {
    if ($FileOrFolderPath = $WebEvent.Data.Value | Test-DriveFileOrFolderPath -Test -Initialize) {
        Remove-Item -Path $FileOrFolderPath -Recurse
        Hide-PodeWebModal
        Sync-PodeWebTable -Id 'DriveExplorer'
    }
}
$ExplorerLinkModal = New-PodeWebModal -Name 'Direct Link' -Id 'DriveLink' -Content @(
    New-PodeWebAlert -Type Info -Id 'DriveLinkText' -Value '[Placeholder]'
)
$ExplorerMainTable = New-PodeWebTable -Name 'Explorer' -Id 'DriveExplorer' -DataColumn Name -Filter -Sort -Click -Paginate -ScriptBlock {
    $DownloadButton = New-PodeWebButton -Name 'Download' -Icon 'Download' -IconOnly -ScriptBlock {
        if ($FileOrFolderPath = $WebEvent.Data.Value | Test-DriveFileOrFolderPath -Test -Initialize) {
            Set-PodeResponseAttachment -Path $FileOrFolderPath
        }
    }
    $DeleteButton = New-PodeWebButton -Name 'Delete' -Icon 'Delete' -IconOnly -ScriptBlock {
        Show-PodeWebModal -Id 'DriveDeleteConfirm' -DataValue $WebEvent.Data.Value -Actions @(
            if ($FileOrFolderPath = $WebEvent.Data.Value | Test-DriveFileOrFolderPath -Test -Initialize) {
                $FileOrFolder = Get-Item -Path $FileOrFolderPath
                $AlertMassage = if ($FileOrFolder -isnot [System.IO.DirectoryInfo]) {
                    "Are you sure you want to delete file `"$($WebEvent.Data.Value)`"?"
                }
                else {
                    "Are you sure you want to delete folder `"$($WebEvent.Data.Value)`" and all of it's content!"
                }
                Out-PodeWebText -Id 'DriveDeleteConfirmAlert' -Value $AlertMassage
            }
        )
    }
    $LinkButton = New-PodeWebButton -Name 'Link' -Icon 'Link' -IconOnly -ScriptBlock {
        Show-PodeWebModal -Id 'DriveLink' -DataValue $WebEvent.Data.Value -Actions @(
            if ($FileOrFolderPath = $WebEvent.Data.Value | Test-DriveFileOrFolderPath -Test -Initialize) {
                Out-PodeWebText -Id 'DriveLinkText' -Value ($Request.UrlReferrer.ToString(), $FileOrFolderPath -join '?value=')
            }
        )
    }
    [ordered]@{
        Icon          = New-PodeWebIcon -Name 'corner-up-left'
        Name          = '..'
        LastWriteTime = ''
        Length        = ''
        Download      = ''
        Delete        = ''
        Link          = ''
    }
    $FolderItems = Get-ChildItem -Path (Initialize-DriveWorkingPath)
    foreach ($FolderItem in $FolderItems) {
        [ordered]@{
            Icon          = $FolderItem | Get-Icon
            Name          = $FolderItem.Name
            LastWriteTime = $FolderItem.LastWriteTime.ToString()
            Length        = $FolderItem.PSObject.Properties.Item('Length').Value | Format-FileSize
            Download      = $DownloadButton
            Delete        = $DeleteButton
            Link          = $LinkButton
        }
    }
}
$ExplorerMainTable | Add-PodeWebTableButton -Name 'Home' -Icon 'Home' -ScriptBlock {
    $WebEvent.Session.Data.DriveWorkingPath = 'Drive:'
    Sync-PodeWebTable -Id 'DriveExplorer'
}
$ExplorerUploadForm = New-PodeWebForm -Name 'Form' -Content @(
    New-PodeWebFileUpload -Name 'Upload File'
    New-PodeWebTextbox -Name 'New Folder'
    New-PodeWebTextbox -Name 'New File'
) -ScriptBlock {
    $DriveWorkingPath = Initialize-DriveWorkingPath

    if ($FilePath = $WebEvent.Data.'Upload File' | Test-DriveFileOrFolderPath) {
        Save-PodeRequestFile -Key 'Upload File' -Path ($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($DriveWorkingPath))
    }
    if ($FolderPath = $WebEvent.Data.'New Folder' | Test-DriveFileOrFolderPath) {
        $null = New-Item -Path $FolderPath -ItemType 'Directory'
    }
    if ($FilePath = $WebEvent.Data.'New File' | Test-DriveFileOrFolderPath) {
        $null = New-Item -Path $FilePath -ItemType 'File'
    }
    Sync-PodeWebTable -Id 'DriveExplorer'
}

$ExplorerCard = New-PodeWebCard -Name 'Explorer' -Content @(
    $ExplorerConfirmModal, $ExplorerLinkModal, $ExplorerUploadForm, $ExplorerMainTable
)

Add-PodeWebPage -Name 'Drive' -Icon Activity -Layouts $ExplorerCard -ScriptBlock {
    $null = Initialize-DriveWorkingPath
    $FileOrFolderName = $WebEvent.Query['value']
    if ([string]::IsNullOrWhiteSpace($FileOrFolderName)) {
        return
    }

    if ($FileOrFolderPath = $FileOrFolderName | Test-DriveFileOrFolderPath -Test) {
        $FileOrFolder = Get-Item -Path $FileOrFolderPath
        if ($FileOrFolder -is [System.IO.DirectoryInfo]) {
            $WebEvent.Session.Data.DriveWorkingPath = $FileOrFolderPath
            Move-PodeResponseUrl -Url ($Request.Url.ToString().Split('?')[0])
        }
        else {
            $FileContent = Get-Content -Path $FileOrFolderPath | Out-String
            New-PodeWebCard -Name "$($FileOrFolderName) Content" -Content @(
                New-PodeWebCodeBlock -Value $FileContent -NoHighlight
            )
        }
    }
    else {
        Move-PodeResponseUrl -Url ($Request.Url.ToString().Split('?')[0])
    }
}