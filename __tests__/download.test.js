const fs = require("fs");
const os = require("os");
const path = require("path");
const http = require("http");

const download = require("../download");
const {
  filenameFromContentDisposition,
  filenameFromUrl,
} = require("../download");

describe("filenameFromContentDisposition", () => {
  it("returns null when there is no header", () => {
    expect(filenameFromContentDisposition(null)).toBeNull();
    expect(filenameFromContentDisposition(undefined)).toBeNull();
    expect(filenameFromContentDisposition("")).toBeNull();
  });

  it("parses an unquoted filename", () => {
    expect(
      filenameFromContentDisposition(
        "attachment; filename=windows-default-manifest-6.4.0-beta.2.tar.gz"
      )
    ).toBe("windows-default-manifest-6.4.0-beta.2.tar.gz");
  });

  it("parses a quoted filename", () => {
    expect(
      filenameFromContentDisposition('attachment; filename="my file.tar.gz"')
    ).toBe("my file.tar.gz");
  });

  it("prefers the RFC 5987 filename* form and decodes it", () => {
    expect(
      filenameFromContentDisposition(
        "attachment; filename=\"fallback.txt\"; filename*=UTF-8''my%20file.tar.gz"
      )
    ).toBe("my file.tar.gz");
  });
});

describe("filenameFromUrl", () => {
  it("uses the basename of the url path", () => {
    expect(filenameFromUrl("https://cygwin.com/setup-x86_64.exe")).toBe(
      "setup-x86_64.exe"
    );
  });

  it("decodes percent-encoded names", () => {
    expect(filenameFromUrl("https://example.com/a/my%20file.tar.gz")).toBe(
      "my file.tar.gz"
    );
  });
});

describe("download", () => {
  let server;
  let baseUrl;

  beforeAll((done) => {
    server = http.createServer((req, res) => {
      if (req.url === "/setup-x86_64.exe") {
        res.writeHead(200, { "content-type": "application/octet-stream" });
        res.end("fake-setup-binary");
      } else if (req.url === "/redirect") {
        res.writeHead(302, { location: `${baseUrl}/archive.tar.gz` });
        res.end();
      } else if (req.url === "/archive.tar.gz") {
        // Mimic GitHub archive downloads, which rename via Content-Disposition.
        res.writeHead(200, {
          "content-type": "application/gzip",
          "content-disposition":
            "attachment; filename=windows-default-manifest-6.4.0-beta.2.tar.gz",
        });
        res.end("fake-tarball");
      } else {
        res.writeHead(404);
        res.end();
      }
    });
    server.listen(0, "127.0.0.1", () => {
      baseUrl = `http://127.0.0.1:${server.address().port}`;
      done();
    });
  });

  afterAll((done) => {
    server.close(done);
  });

  it("names the file from the url basename when there is no header", async () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), "esy-bash-dl-"));
    const dest = await download(`${baseUrl}/setup-x86_64.exe`, dir);
    expect(path.basename(dest)).toBe("setup-x86_64.exe");
    expect(fs.readFileSync(dest, "utf8")).toBe("fake-setup-binary");
  });

  it("follows redirects and names the file from Content-Disposition", async () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), "esy-bash-dl-"));
    const dest = await download(`${baseUrl}/redirect`, dir);
    expect(path.basename(dest)).toBe(
      "windows-default-manifest-6.4.0-beta.2.tar.gz"
    );
    expect(fs.readFileSync(dest, "utf8")).toBe("fake-tarball");
  });

  it("rejects on a non-ok response", async () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), "esy-bash-dl-"));
    await expect(download(`${baseUrl}/missing`, dir)).rejects.toThrow();
  });
});
