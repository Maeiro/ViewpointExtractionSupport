param(
    [Parameter(Mandatory = $true)] [string]$ViewpointJar,
    [Parameter(Mandatory = $true)] [string]$CompileViewpointJar,
    [string]$JavaExe = 'java'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$classes = Join-Path $root ('build\flare-tests-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $classes | Out-Null
$fixtures = Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'flare\java') -Recurse -Filter '*.java' -File
$source = Join-Path $root 'src\maeiro\viewpointextractionsupport\FlareEffects.java'
& javac --release 17 -cp $CompileViewpointJar -d $classes $source $fixtures.FullName
if ($LASTEXITCODE -ne 0) { throw 'Flare test compilation failed.' }
& $JavaExe -cp ($classes + ';' + $ViewpointJar) maeiro.viewpointextractionsupport.FlareEffectsTest
if ($LASTEXITCODE -ne 0) { throw 'Flare regression checks failed.' }
