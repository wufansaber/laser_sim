param(
    [Parameter(Mandatory=$true)][string]$InputDocx,
    [Parameter(Mandatory=$true)][string]$OutputPdf
)
$wordApp = $null
$doc = $null
try {
    $wordApp = New-Object -ComObject Word.Application
    $wordApp.Visible = $false
    $wordApp.DisplayAlerts = 0
    $doc = $wordApp.Documents.Open($InputDocx, $false, $true)
    $doc.ExportAsFixedFormat($OutputPdf, 17)
}
finally {
    if ($null -ne $doc) { $doc.Close($false) }
    if ($null -ne $wordApp) { $wordApp.Quit() }
    if ($null -ne $doc) { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($doc) | Out-Null }
    if ($null -ne $wordApp) { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($wordApp) | Out-Null }
}
