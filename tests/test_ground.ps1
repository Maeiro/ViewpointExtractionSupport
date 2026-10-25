param(
    [Parameter(Mandatory = $true)]
    [string]$ViewpointJar
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$dependency = (Resolve-Path -LiteralPath $ViewpointJar).Path
$classes = Join-Path $root ('build\ground-tests-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $classes | Out-Null
$fixtures = Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'ground\java') -Recurse -Filter '*.java' -File
$sources = @(
    (Join-Path $root 'src\maeiro\viewpointextractionsupport\GroundAreas.java'),
    (Join-Path $root 'src\maeiro\viewpointextractionsupport\ExtractionArrows.java')
)
& javac --release 17 -cp $dependency -d $classes $sources $fixtures.FullName
if ($LASTEXITCODE -ne 0) { throw 'Ground area test compilation failed.' }
& java -cp ($classes + ';' + $dependency) GroundAreasTest
if ($LASTEXITCODE -ne 0) { throw 'Ground area regression checks failed.' }
