type path = string;
let environmentFile: ref(option(path)) = ref(None);
let usageMsg = "EsyBash [--env /path/environment-file] command and args ...";
let commandAndArgs: ref(list(string)) = ref([]);
let msvc: ref(bool) = ref(false);

let rest = command => {
  commandAndArgs := command;
};

let specList = [
  (
    "--env",
    Arg.String(path => environmentFile := Some(path)),
    "Set the environment file. Contains variables in the format similar to the output of env command ie. A=B ...",
  ),
  (
    "--msvc",
    Arg.Set(msvc),
    "Run in MSVC mode. 1. Append (instead of prepend) /usr/bin and other cygwin paths",
  ),
  ("--", Arg.Rest_all(rest), "Pass command to underlying bash"),
];

let parse = () => Arg.parse(specList, _ => (), usageMsg);
