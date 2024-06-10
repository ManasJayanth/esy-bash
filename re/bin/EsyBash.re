let serialiseAsOneCommand = args => {
  let sanitizedArgs =
    switch (Array.length(args)) {
    | 1 => args
    | _ => Array.map(a => "\"" ++ a ++ "\"", args)
    };

  String.concat(" ", Array.to_list(sanitizedArgs));
};

let sysArgvLen = Array.length(Sys.argv);

/* Argument parsing could be improved I guess, simply copied from current logic */
let exitCode = {
  ArgParser.parse();
  let msvc = ArgParser.msvc^;
  switch (ArgParser.environmentFile^) {
  | Some(environmentFile) =>
    ArgParser.commandAndArgs^
    |> Array.of_list
    |> serialiseAsOneCommand
    |> EsyBashLib.bashExec(~environmentFile, ~msvc)
  | None =>
    ArgParser.commandAndArgs^
    |> Array.of_list
    |> serialiseAsOneCommand
    |> EsyBashLib.bashExec(~msvc)
  };
};

exit(exitCode);
