const {
  cygwin: {
    installationSubDirectory,
    setupWebsite: cygwinSetupWebsite,
    setup: cygwinSetup,
    mirror: cygwinMirror,
  },
  paths: { esyBashExe },
} = require("./config");

const cygwinSetupDownloadURL = `${cygwinSetupWebsite}/${cygwinSetup}`;

// paths that need __dirname
const esyBashExePath = path.join(__dirname, esyBashExe);
const installationSubDirectory = path.join(__dirname, installationSubDirectory);

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
