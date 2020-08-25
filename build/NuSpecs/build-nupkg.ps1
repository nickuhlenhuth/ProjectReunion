[CmdLetBinding()]
Param(
    [string]$BuildOutput,
    [string]$OutputDir,
    [string]$VersionOverride,
    [string]$Subversion = "",
    [string]$DateOverride,
    [string]$prereleaseversion,
    [string]$BuildFlavor = "release",
    [string]$BuildArch = "x86",
    [switch]$NoDeleteTemp,
    [switch]$SkipFrameworkPackage = $true
)

#
# Version is read from the VERSION file.
#

$scriptDirectory = $script:MyInvocation.MyCommand.Path | Split-Path -Parent

pushd $scriptDirectory

if (!$OutputDir)
{
    $OutputDir = $scriptDirectory
}

if (!$BuildOutput)
{
    Write-Host "Must specify BuildOutput parameter" -ForegroundColor Red
    Exit 1
}

if ($VersionOverride)
{
    $version = $VersionOverride
}
else
{
    [xml]$customProps = (Get-Content ..\..\version.props)
    $versionMajor = $customProps.GetElementsByTagName("ProjectReunionVersionMajor").'#text'
    $versionMinor = $customProps.GetElementsByTagName("ProjectReunionVersionMinor").'#text'
    $versionPatch = $customProps.GetElementsByTagName("ProjectReunionVersionPatch").'#text'

    if ((!$versionMajor) -or (!$versionMinor) -or (!$versionPatch))
    {
        Write-Error "Expected ProjectReunionVersionMajor, ProjectReunionVersionMinor, and ProjectReunionVersionPatch tags to be in version.props file"
        Exit 1
    }

    $version = "$versionMajor.$versionMinor.$versionPatch"

    Write-Verbose "Version = $version"
}

if ($prereleaseversion)
{
    $versiondate = $DateOverride
    if (-not $versiondate)
    {
        $pstZone = [System.TimeZoneInfo]::FindSystemTimeZoneById("Pacific Standard Time")
        $pstTime = [System.TimeZoneInfo]::ConvertTimeFromUtc((Get-Date).ToUniversalTime(), $pstZone)
        $versiondate += ($pstTime).ToString("yyMMdd")
    }

    $version = "$version-$prereleaseversion.$versiondate$subversion"
   
}

if (!(Test-Path $OutputDir)) { mkdir $OutputDir }

$nupkgtitle = "Microsoft.ProjectReunion"

function New-TemporaryDirectory {
    $parent = [System.IO.Path]::GetTempPath()
    $name = [System.IO.Path]::GetRandomFileName()
    New-Item -ItemType Directory -Path (Join-Path $parent $name)
}

function Copy-IntoNewDirectory {
    Param($source, $destinationDir, [switch]$IfExists = $false)

    if ((-not $IfExists) -or (Test-Path $source))
    {
        Write-Verbose "Copy from '$source' to '$destinationDir'"
        if (-not (Test-Path $destinationDir))
        {
            $ignore = New-Item -ItemType Directory $destinationDir
        }
        Copy-Item -Recurse -Force $source $destinationDir
    }
}

$TempDir = New-TemporaryDirectory

Write-Verbose "TempDir = $($TempDir.FullName)"

# nuspecs can't have conditionals so copy the contents of the runtime folder over, skipping arm64 if those sources aren't
# created in this particular build.
$runtimesDir = "$($TempDir.FullName)\runtimes"
$toolsDir = "$($TempDir.FullName)\tools"

Copy-IntoNewDirectory -IfExists $BuildOutput\$BuildFlavor\x86\Microsoft.ProjectReunion\Microsoft.ProjectReunion.dll "$runtimesDir\win10-x86\native"
Copy-IntoNewDirectory -IfExists $BuildOutput\$BuildFlavor\x86\Microsoft.ProjectReunion\Microsoft.ProjectReunion.pri "$runtimesDir\win10-x86\native"
Copy-IntoNewDirectory -IfExists $BuildOutput\$BuildFlavor\x64\Microsoft.ProjectReunion\Microsoft.ProjectReunion.dll "$runtimesDir\win10-x64\native"
Copy-IntoNewDirectory -IfExists $BuildOutput\$BuildFlavor\x64\Microsoft.ProjectReunion\Microsoft.ProjectReunion.pri "$runtimesDir\win10-x64\native"
Copy-IntoNewDirectory -IfExists $BuildOutput\$BuildFlavor\arm\Microsoft.ProjectReunion\Microsoft.ProjectReunion.dll "$runtimesDir\win10-arm\native"
Copy-IntoNewDirectory -IfExists $BuildOutput\$BuildFlavor\arm\Microsoft.ProjectReunion\Microsoft.ProjectReunion.pri "$runtimesDir\win10-arm\native"
Copy-IntoNewDirectory -IfExists $BuildOutput\$BuildFlavor\arm64\Microsoft.ProjectReunion\Microsoft.ProjectReunion.dll "$runtimesDir\win10-arm64\native"
Copy-IntoNewDirectory -IfExists $BuildOutput\$BuildFlavor\arm64\Microsoft.ProjectReunion\Microsoft.ProjectReunion.pri "$runtimesDir\win10-arm64\native"

$CommonNugetArgs = "-properties `"BuildOutput=$BuildOutput``;ID=$nupkgtitle``;RUNTIMESDIR=$runtimesDir`;TOOLSDIR=$toolsDir`;BUILDFLAVOR=$($BuildFlavor)`;BUILDARCH=$($BuildArch)`""

$NugetArgs = "$CommonNugetArgs -OutputDirectory $OutputDir"

$nugetExe = "$scriptDirectory\..\..\tools\NugetWrapper.cmd"
$NugetCmdLine = "$nugetExe pack ProjectReunion.nuspec $NugetArgs -version $version"
Write-Host $NugetCmdLine
Invoke-Expression $NugetCmdLine
if ($lastexitcode -ne 0)
{
    Write-Host "Nuget returned $lastexitcode"
    Exit $lastexitcode; 
}

Write-Host
Write-Host "SkipFrameworkPackage = $SkipFrameworkPackage"
Write-Host

if(-not $SkipFrameworkPackage)
{
    # Nuget package with framework package encapsulation
    $NugetArgs = "$CommonNugetArgs -OutputDirectory $OutputDir\FrameworkPackage"

    Copy-IntoNewDirectory -IfExists $BuildOutput\$BuildFlavor\x86\FrameworkPackage\Microsoft.ProjectReunion.*.appx "$toolsDir\AppX\x86\Release"
    Copy-IntoNewDirectory -IfExists $BuildOutput\$BuildFlavor\x64\FrameworkPackage\Microsoft.ProjectReunion.*.appx "$toolsDir\AppX\x64\Release"
    Copy-IntoNewDirectory -IfExists $BuildOutput\$BuildFlavor\arm\FrameworkPackage\Microsoft.ProjectReunion.*.appx "$toolsDir\AppX\arm\Release"
    Copy-IntoNewDirectory -IfExists $BuildOutput\$BuildFlavor\arm64\FrameworkPackage\Microsoft.ProjectReunion.*.appx "$toolsDir\AppX\arm64\Release"
    # Currently we don't have a separate Debug package that we want to ship to customers
    #Copy-IntoNewDirectory -IfExists $BuildOutput\debug\x86\FrameworkPackage\Microsoft.ProjectReunion.Debug.*.appx "$toolsDir\AppX\x86\Debug"
    #Copy-IntoNewDirectory -IfExists $BuildOutput\debug\x64\FrameworkPackage\Microsoft.ProjectReunion.Debug.*.appx "$toolsDir\AppX\x64\Debug"
    #Copy-IntoNewDirectory -IfExists $BuildOutput\debug\arm\FrameworkPackage\Microsoft.ProjectReunion.Debug.*.appx "$toolsDir\AppX\arm\Debug"
    #Copy-IntoNewDirectory -IfExists $BuildOutput\debug\arm64\FrameworkPackage\Microsoft.ProjectReunion.Debug.*.appx "$toolsDir\AppX\arm64\Debug"

    $NugetCmdLine = "$nugetExe pack ProjectReunionFrameworkPackage.nuspec $NugetArgs -version $version"
    Write-Host $NugetCmdLine
    Invoke-Expression $NugetCmdLine
    if ($lastexitcode -ne 0)
    {
        Write-Host "Nuget returned $lastexitcode"
        Exit $lastexitcode; 
    }
}

if (-not $NoDeleteTemp)
{
    Remove-Item -Recurse -Force "$($TempDir.FullName)"
}

popd