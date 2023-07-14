function downloadWindowsDefaultManifest($configJson, $downloadFolder) {
    $ghAccount = $configJson.windowsDefaultManifest.ghAccount;
    $name = $configJson.windowsDefaultManifest.name;
    $version = $configJson.windowsDefaultManifest.version;
    $tag = "v$version"
    $archiveType = "tar.gz"
    $windowsDefaultManifestArchiveUri = "https://github.com/$ghAccount/$name/archive/refs/tags/$tag.$archiveType"
    $archiveName = "$name-$version.$archiveType";
    $archivePath = Join-Path -Path $downloadFolder -ChildPath $archiveName
    if (! (Test-Path $archivePath -PathType Leaf)) {
	Invoke-WebRequest -Uri $windowsDefaultManifestArchiveUri -OutFile $archivePath
    }
    $PublishedHash = "2385d027d83db3bbd6fadca92cb93d5b95fcbb5d42a7c481e164f62998a0338f"
    $FileHash = Get-FileHash $archivePath -Algorithm SHA256
    if (! ($FileHash.Hash -eq $PublishedHash)) {
	echo "Checksum failure. Exiting"
	exit -1
    }
    tar -C $workspaceArea -xvf $archivePath
    $uncompressedPath = Join-Path -Path $downloadFolder -ChildPath "$name-$version";
    return $uncompressedPath
}

$EsyBash = "./re/_build/default/bin/EsyBash.exe"

function runEsy {
    param([String] $Path, $Cmd)
    $Cwd = $(pwd)
    cd $Path
    & $EsyBash $Cmd
    if (! $?) {
	exit(-1);
    }
    cd $Cwd
}

function buildAndInstall ($src) {
    runEsy -Path $src "./configure --host x86_64-w64-mingw32 --prefix=/usr/x86_64-w64-mingw32/sys-root/mingw"
    runEsy -Path $src "make"
    runEsy -Path $src "make install"
}

$workspaceAreaName = "_temp"
mkdir -p $workspaceAreaName
$workspaceArea = Resolve-Path $workspaceAreaName
$configJson = Get-Content ./config.json -Raw | ConvertFrom-Json 
$windowsDefaultManifestSrc = downloadWindowsDefaultManifest $configJson $workspaceArea
buildAndInstall $windowsDefaultManifestSrc
