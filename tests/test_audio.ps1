param(
    [Parameter(Mandatory = $true)]
    [string]$VisibleHelicopterJar
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$dependency = (Resolve-Path -LiteralPath $VisibleHelicopterJar).Path
$classes = Join-Path $root ('build\audio-tests-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $classes | Out-Null
$fixtures = Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'java') -Recurse -Filter '*.java' -File
$source = Join-Path $root 'src\maeiro\viewpointextractionsupport\ExtractionAudio.java'
& javac --release 17 -cp $dependency -d $classes $source $fixtures.FullName
if ($LASTEXITCODE -ne 0) { throw 'Audio test compilation failed.' }
& java -cp ($classes + ';' + $dependency) ExtractionAudioTest
if ($LASTEXITCODE -ne 0) { throw 'Audio regression checks failed.' }
