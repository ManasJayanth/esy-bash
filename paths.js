const path = require("path");
const {
  cygwin: {
    localPackageSubDirectory,
    installationSubDirectory,
    setupWebsite: cygwinSetupWebsite,
    setup: cygwinSetup,
    mirror: cygMirror,
  },
  paths: { esyBashExe },
} = require("./config");

const cygwinSetupDownloadURL = `${cygwinSetupWebsite}/${cygwinSetup}`;

// paths that need __dirname
const esyBashExePath = path.join(__dirname, esyBashExe);
const installationDirectory = path.join(__dirname, installationSubDirectory);

// paths that need __dirname indirectly
const localPackageDirectory = path.join(
  installationDirectory,
  localPackageSubDirectory
);

module.exports = {
  cygMirror,
  cygwinSetup,
  cygwinSetupDownloadURL,
  installationDirectory,
  localPackageDirectory,
  esyBashExePath,
};
