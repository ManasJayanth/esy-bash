const { packages: packagesToInstall } = require("./config");

module.exports = [
  // Needed for cross-compilation to Windows native executables
  ...packagesToInstall.gcc,

  // Linux utilities - 'bashisms' to support development
  ...packagesToInstall.bashUtils,

  // Needed for installing the cygwin-build of OCaml
  // May not be needed
  // ...packagesToInstall.cygwinOCaml,
];
