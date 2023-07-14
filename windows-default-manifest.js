const {
  windowsDefaultManifest: { name, version, ghAccount },
} = require("./config");

let tag = `v${version}`;
let tarballURL = `https://github.com/${ghAccount}/${name}/archive/refs/tags/${tag}.tar.gz`;
let tarballName = `${name}-${version}.tar.gz`;

module.exports = { name, version, tag, version, tarballURL, tarballName };
