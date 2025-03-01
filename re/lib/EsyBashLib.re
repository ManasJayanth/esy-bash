exception InvalidEnvJSON(string);
exception InvariantViolation(unit);

let pathDelimStr = Sys.unix ? "/" : "\\";
let pathDelimChr = pathDelimStr.[0];

let log = msg => {
  let debugMode =
    (
      try(Sys.getenv("ESY_BASH_DEBUG")) {
      | Not_found => ""
      }
    )
    != "";
  if (debugMode) {
    print_endline(msg);
  };
};

let normalizePath = str =>
  String.concat("/", String.split_on_char(pathDelimChr, str));

let normalizeEndlines = str =>
  String.concat("\n", Str.split(Str.regexp("\r\n"), str));

let splitInTwo = (~char, str) => {
  switch (String.split_on_char(char, str)) {
  | [] => Error("String.split_on_char returned empty list")
  | [_] => Error("String.split_on_char returned a single item back")
  | [a, b, ..._] => Ok((a, b))
  };
};

let getPathSeparator = () => {
  Sys.unix ? ":" : ";";
};

module Array = {
  include Array;
  let filter_map = (f, arr) => {
    arr
    |> Array.fold_left(
         (acc, a) =>
           switch (f(a)) {
           | Some(v) => [v, ...acc]
           | None => acc
           },
         [],
       )
    |> Array.of_list;
  };
};

let remapPathsInEnvironment = envVars => {
  let ( let* ) = Option.bind;
  let f = envVar => {
    let* (k, v) = Result.to_option(splitInTwo(~char='=', envVar));
    switch (String.lowercase_ascii(k)) {
    | "path" =>
      Some((
        "PATH",
        String.concat(
          getPathSeparator(),
          [normalizePath(v), "/usr/bin", "/usr/local/bin"],
        ),
      ))
    | "home" => Some(("HOME", "/usr/esy"))
    | "" => None
    | _kLowerCase => Some((k, v))
    };
  };
  envVars
  |> Array.filter_map(f)  // Some env vars could be invalid and need to be filtered out
  |> Array.map(((k, v)) => Printf.sprintf("%s=%s", k, v));
};

let collectKeyValuePairs = jsonKeyValuePairs =>
  List.map(
    pair => {
      let (k, jsonValue) = pair;
      switch (jsonValue) {
      | `String(a) => k ++ "=" ++ a
      | _ => raise(InvalidEnvJSON("Not a valid env json file"))
      };
    },
    jsonKeyValuePairs,
  );

let rec traverse = json =>
  switch (json) {
  | `Assoc(keyValuePairs) => collectKeyValuePairs(keyValuePairs)
  | _ => raise(InvalidEnvJSON("Not a valid env json file"))
  };

let extractEnvironmentVariables = environmentFile => {
  let json = Yojson.Basic.from_file(environmentFile);
  traverse(json);
};

let withTempFile = (~contents, ~f) => {
  let tempFilePath = Filename.temp_file("__esy-bash__", ".sh");
  let fileChannel = open_out_bin(tempFilePath);
  Printf.fprintf(fileChannel, "%s", contents);
  close_out(fileChannel);
  let result = f(tempFilePath);
  Sys.remove(tempFilePath);
  result;
};

let bashExec = (~environmentFile=?, command) => {
  let executablePath = Sys.executable_name;
  let parent = Filename.dirname;
  let cygwinBash =
    parent(parent(parent(parent(parent(executablePath)))))
    ++ "\\.cygwin\\bin\\bash.exe";
  let shellPath = Sys.unix ? "/bin/bash" : cygwinBash;
  log(Printf.sprintf("esy-bash: executing bash command: %s\n", command));
  if (Sys.win32) {
    let bashCommandWithDirectoryPreamble =
      Printf.sprintf(
        "mount -c /cygdrive -o binary,noacl,posix=0,user > /dev/null; \ncd \"%s\";\n%s;",
        normalizePath(Sys.getcwd()),
        command,
      );
    let normalizedShellScript =
      normalizeEndlines(bashCommandWithDirectoryPreamble);
    let cygwinSymlinkVar = "CYGWIN=winsymlinks:nativestrict";
    let existingVars = Unix.environment();
    let vars =
      remapPathsInEnvironment(
        Array.append([|cygwinSymlinkVar|], existingVars),
      );
    withTempFile(
      ~contents=normalizedShellScript,
      ~f=tempFilePath => {
        let run_shell =
          switch (environmentFile) {
          | Some(x) =>
            let varsFromFile =
              remapPathsInEnvironment(
                Array.of_list(extractEnvironmentVariables(x)),
              );
            Unix.create_process_env(
              shellPath,
              [|Sys.unix ? "-c" : "-lc", tempFilePath|],
              Array.append(existingVars, varsFromFile),
            );
          | None =>
            Unix.create_process_env(
              shellPath,
              [|Sys.unix ? "-c" : "-lc", tempFilePath|],
              vars,
            )
          };
        let pid = run_shell(Unix.stdin, Unix.stdout, Unix.stderr);
        switch (Unix.waitpid([], pid)) {
        | (_, WEXITED(c)) => c
        | (_, WSIGNALED(c)) => c
        | (_, WSTOPPED(c)) => c
        };
      },
    );
  } else {
    let env =
      switch (environmentFile) {
      | Some(x) => Array.of_list(extractEnvironmentVariables(x))
      | None => Unix.environment()
      };

    let run_shell =
      Unix.create_process_env(shellPath, [|shellPath, "-c", command|], env);
    let pid = run_shell(Unix.stdin, Unix.stdout, Unix.stderr);
    switch (Unix.waitpid([], pid)) {
    | (_, WEXITED(c)) => c
    | (_, WSIGNALED(c)) => c
    | (_, WSTOPPED(c)) => c
    };
  };
};
