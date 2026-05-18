[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$NuGetApiKey,

    [Parameter(Mandatory = $false)]
    [string]$Repository = 'PSGallery'
)

$modulePath = "$PSScriptRoot/src/BicepConsoleTTK"
$readmeSrc  = "$PSScriptRoot/README.md"
$readmeDst  = "$modulePath/README.md"

Copy-Item -Path $readmeSrc -Destination $readmeDst -Force
try {
    Publish-Module -Path $modulePath -NuGetApiKey $NuGetApiKey -Repository $Repository
} finally {
    Remove-Item -Path $readmeDst -ErrorAction SilentlyContinue
}
