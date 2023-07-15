
##############
# Parameters #
##############

param([String] $EsyBashExe, [String] $EsyBashRoot)
if (! $EsyBashExe) {
    $EsyBashExe = Resolve-Path "./re/_build/default/bin/EsyBash.exe"
}
if (! $EsyBashRoot) {
    $EsyBashRoot = $PWD;
}

###############
# Load Config #
###############

$configJsonPath = Join-Path -Path $EsyBashRoot -ChildPath config.json
$configJson = Get-Content $configJsonPath -Raw | ConvertFrom-Json 

#########
# Utils #
#########

function pathExists {
    param([String] $Path)
    return (Test-Path $Path)
}

function removePath {
    param([String] $Path)
    rm -Recurse -Force -ErrorAction SilentlyContinue $Path
}

function createEmptyFolder {
    param([String] $Path)
    removePath -Path $Path
    mkdir $Path | Out-Null
    return Resolve-Path $Path;
}

##################################
# windows-default-manifest setup #
##################################

function prepareWindowsDefaultManifestSrc {
    param([String] $dotCygwinFolder)
    $name = $configJson.windowsDefaultManifest.name;
    $version = $configJson.windowsDefaultManifest.version;
    $publishedHash256 = $configJson.windowsDefaultManifest.publishedHash256;
    $localPackageDirectory = Resolve-Path -Path ([IO.Path]::Combine($dotCygwinFolder, $configJson.cygwin.localPackageSubDirectory))
    $tag = "v$version"
    $archiveType = "tar.gz"
    $archiveName = "$name-$version.$archiveType";
    $archivePath = Resolve-Path -Path ([IO.Path]::Combine($localPackageDirectory, $archiveName))
    if (! (pathExists -Path archivePath)) {
	$FileHash = Get-FileHash $archivePath -Algorithm SHA256
	if (! ($FileHash.Hash -eq $publishedHash256)) {
	    echo "windows-default-manifest tarball found, but possibly corrupt." # TODO prompt for download
	    # $ghAccount = $configJson.windowsDefaultManifest.ghAccount;
	    # $windowsDefaultManifestArchiveUri = "https://github.com/$ghAccount/$name/archive/refs/tags/$tag.$archiveType"
	    # Invoke-WebRequest -Uri $windowsDefaultManifestArchiveUri -OutFile $archivePath
	    exit -1;
	}
    } else {
	echo "windows-default-manifest tarball not found." # TODO prompt for download
	exit -1
    }
    $uncompressedPath = Resolve-Path -Path ([IO.Path]::Combine($localPackageDirectory, "$name-$version"));
    removePath -Path $uncompressedPath
    tar -C $localPackageDirectory -xvf $archivePath
    return $uncompressedPath
}

function runCommand {
    param([String] $Cwd, [String] $Prg, $ArgsString)
    $curCwd = $(pwd)
    if (!$Cwd) {
	$Cwd = $curCwd;
    }
    cd $Cwd
    Start-Process -NoNewWindow -Wait $Prg $ArgsString
    cd $curCwd
    if (! $?) {
	exit(-1);
    }
}

function runEsyBash {
    param([String] $Cwd, $Cmd)
    runCommand -Cwd $Cwd -Prg $EsyBashExe -ArgsString $Cmd 
}

function runSetup ($ArgsString) {
    $setup = $configJson.cygwin.setup
    runCommand -Prg "./$setup" -ArgsString $ArgsString
}

function buildAndInstall ($windowsDefaultManifestSrcPath) {
    runEsyBash -Cwd $windowsDefaultManifestSrcPath "./configure --host x86_64-w64-mingw32 --prefix=/usr/x86_64-w64-mingw32/sys-root/mingw"
    runEsyBash -Cwd $windowsDefaultManifestSrcPath "make"
    runEsyBash -Cwd $windowsDefaultManifestSrcPath "make install"
}

function setupCygwin {
    param([String] $EsyBashRoot, [String] $dotCygwinFolder)

    $installationDirectory = Join-Path -Path $EsyBashRoot -ChildPath $configJson.cygwin.installationSubDirectory
    $localPackageDirectory = Join-Path -Path $installationDirectory $configJson.cygwin.localPackageSubDirectory

    echo "Installing packages"
    $packagesToInstall = $configJson.packages.gcc +
    $configJson.bashUtils
    $packagesToInstall = $packagesToInstall -Join ","
    runSetup "-qWnNdO -R $installationDirectory -L -l $localPackageDirectory -P $packagesToInstall"

    echo "Copying over defaults..."
    $DefaultsFolder = Join-Path -Path $EsyBashRoot -ChildPath "defaults"
    cp -Recurse "$DefaultsFolder/*" $dotCygwinFolder -ErrorAction SilentlyContinue 
    $nsSwitchConf = [IO.Path]::Combine($dotCygwinFolder, "etc", "nsswitch.conf")
    Add-Content -Path $nsSwitchConf -Value "\ndb_home: /usr/esy\n"
    echo "Verifying esy profile set up..."
    runEsyBash -Cmd "bash -lc cd ~ && pwd"
    if (Test-Path ([IO.Path]::Combine($dotCygwinFolder, "usr", "esy", ".bashrc"))) {
	echo "Esy user profile setup!"
    } else {
	echo "Esy user profile not setup. Exiting"
	exit -1
    }
}

function setupWindowsDefaultManifest {
    param([String] $dotCygwinFolder)
    $windowsDefaultManifestSrc = prepareWindowsDefaultManifestSrc -dotCygwinFolder $dotCygwinFolder
    buildAndInstall $windowsDefaultManifestSrc
}

function installEsyBash {
    param([String] $EsyBashExe, [String] $EsyBashRoot, [String] $dotCygwinFolder)
    setupCygwin -EsyBashRoot $EsyBashRoot -dotCygwinFolder $dotCygwinFolder
    setupWindowsDefaultManifest -dotCygwinFolder $dotCygwinFolder
}

function main {
 
    param([String] $EsyBashExe, [String] $EsyBashRoot)

    # This is necessary because on the CI (or during local
    # development, runnning `npm install` will trigger postinstall
    # too. We dont want this to fail, esp on CI where it will break
    # the pipeline unnecessarily. The point of this `npm install`
    # command was only to setup dependencies needs to work with
    # esy-bash. A working postinstall at this stage (beginning of
    # development) isn't necessary.

    $dotCygwinFolder = ".cygwin"
    if (!(pathExists -Path $dotCygwinFolder)) {
	echo "No cygwin folder found, nothing to be done.";
	exit 0;
    }

    installEsyBash -EsyBashExe $EsyBashExe -EsyBashRoot $EsyBashRoot -dotCygwinFolder $dotCygwinFolder
}

main -EsyBashExe $EsyBashExe -EsyBashRoot $EsyBashRoot 
