Function Format-FileSize {
    Param (
        [Parameter(ValueFromPipeline)]
        $Size
    )
    if ($Size -gt 1TB) { '{0:0.##} TB' -f ($Size / 1TB) }
    elseif ($Size -ge 1GB) { '{0:0.##} GB' -f ($Size / 1GB) }
    elseif ($Size -ge 1MB) { '{0:0.##} MB' -f ($Size / 1MB) }
    elseif ($Size -ge 1KB) { '{0:0.##} kB' -f ($Size / 1KB) }
    elseif ($Size -ge 0) { '{0:0.##} B' -f $Size }
    else { '' }
}
Function Get-Icon {
    Param (
        [Parameter(ValueFromPipeline)]
        $InputObject
    )
    # https://feathericons.com/
    $Icon = if ($InputObject -is [System.IO.DirectoryInfo]) { 'Folder' }
    else {
        switch ($InputObject.Extension) {
            '.txt' { 'type' ; break }
            '.ps1' { 'battery-charging' ; break }
            Default {
                if ($InputObject.Length -eq 0) {
                    'file'
                }
                else {
                    'file-text'
                }
            }
        }
    }
    New-PodeWebIcon -Name $Icon
}