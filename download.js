const fs = require("fs");
const path = require("path");
const { Readable } = require("stream");
const { pipeline } = require("stream/promises");

// Parse a file name out of a Content-Disposition header value, supporting both
// the RFC 5987 `filename*` form (which takes precedence) and the plain
// `filename` form. Returns null when no file name can be found.
function filenameFromContentDisposition(header) {
  if (!header) {
    return null;
  }

  // filename*=UTF-8''percent%20encoded.ext
  const extended = /filename\*\s*=\s*[^']*'[^']*'([^;]+)/i.exec(header);
  if (extended) {
    try {
      return decodeURIComponent(extended[1].trim());
    } catch (e) {
      // Malformed percent-encoding; fall through to the plain form.
    }
  }

  // filename="quoted.ext" or filename=plain.ext
  const plain = /filename\s*=\s*"?([^";]+)"?/i.exec(header);
  if (plain) {
    return plain[1].trim();
  }

  return null;
}

function filenameFromUrl(urlString) {
  const base = path.posix.basename(new URL(urlString).pathname);
  try {
    return decodeURIComponent(base);
  } catch (e) {
    return base;
  }
}

// Minimal replacement for the `download` npm package, covering the only use
// case in this project: fetch a URL (following redirects) and write the
// response body to a folder. The file name is taken from the response's
// Content-Disposition header when present (e.g. GitHub archive downloads) and
// otherwise derived from the final URL's basename. Resolves to the absolute
// path of the written file.
async function download(url, destinationFolder) {
  const response = await fetch(url, { redirect: "follow" });
  if (!response.ok) {
    throw new Error(
      `Failed to download ${url}: ${response.status} ${response.statusText}`
    );
  }

  const fileName =
    filenameFromContentDisposition(
      response.headers.get("content-disposition")
    ) || filenameFromUrl(response.url || url);

  await fs.promises.mkdir(destinationFolder, { recursive: true });
  const destinationPath = path.join(destinationFolder, fileName);

  await pipeline(
    Readable.fromWeb(response.body),
    fs.createWriteStream(destinationPath)
  );

  return destinationPath;
}

module.exports = download;
module.exports.filenameFromContentDisposition = filenameFromContentDisposition;
module.exports.filenameFromUrl = filenameFromUrl;
