param(
    [Parameter(Mandatory = $true)]
    [string]$ZombieBuddyJar
)

$ErrorActionPreference = 'Stop'
$dependency = (Resolve-Path -LiteralPath $ZombieBuddyJar).Path
$classes = Join-Path $PSScriptRoot ('build\classes-' + [Guid]::NewGuid().ToString('N'))
$output = Join-Path $PSScriptRoot '42\media\java\client\ViewpointExtractionSupport.jar'
New-Item -ItemType Directory -Force -Path $classes, (Split-Path -Parent $output) | Out-Null
$sources = Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'src') -Recurse -Filter '*.java' -File
& javac --release 17 -cp $dependency -d $classes $sources.FullName
if ($LASTEXITCODE -ne 0) { throw 'Java compilation failed.' }
& jar --create --file $output -C $classes maeiro
if ($LASTEXITCODE -ne 0) { throw 'JAR packaging failed.' }
Write-Output $output
