const path = require("path");
const vscode = require("vscode");

const output = vscode.window.createOutputChannel("ZEMI Python Environment");
const applying = new Map();

async function exists(uri, type) {
  try {
    const stat = await vscode.workspace.fs.stat(uri);
    return (stat.type & type) !== 0;
  } catch {
    return false;
  }
}

function expandVariables(value, folder) {
  return value.replace(/\$\{([^}]+)\}/g, (match, name) => {
    if (name === "workspaceFolder") return folder.uri.fsPath;
    if (name === "workspaceFolderBasename") return path.basename(folder.uri.fsPath);
    if (name.startsWith("workspaceFolder:")) {
      const requested = name.slice("workspaceFolder:".length);
      return vscode.workspace.workspaceFolders?.find((item) => item.name === requested)?.uri.fsPath ?? match;
    }
    if (name.startsWith("env:")) return process.env[name.slice(4)] ?? "";
    return match;
  });
}

async function resolveConfiguredInterpreter(folder) {
  const configured = vscode.workspace
    .getConfiguration("python", folder.uri)
    .get("defaultInterpreterPath", "")
    .trim();
  if (!configured || configured === "python") return undefined;

  const expanded = expandVariables(configured, folder);
  if (expanded.includes("${")) {
    throw new Error(`Unsupported variable in python.defaultInterpreterPath: ${configured}`);
  }

  const absolute = path.isAbsolute(expanded)
    ? expanded
    : path.resolve(folder.uri.fsPath, expanded);
  const configuredUri = vscode.Uri.file(absolute);
  if (await exists(configuredUri, vscode.FileType.File)) return configuredUri;

  for (const relative of [["Scripts", "python.exe"], ["python.exe"], ["bin", "python"]]) {
    const candidate = vscode.Uri.joinPath(configuredUri, ...relative);
    if (await exists(candidate, vscode.FileType.File)) return candidate;
  }
  throw new Error(`python.defaultInterpreterPath was not found: ${absolute}`);
}

async function pythonEnvironmentsApi() {
  const extension = vscode.extensions.getExtension("ms-python.vscode-python-envs");
  if (!extension) throw new Error("Install Microsoft Python Environments.");
  if (!extension.isActive) await extension.activate();
  if (!extension.exports) {
    throw new Error(
      'Python Environments API is unavailable. Enable "python.useEnvironmentsExtension" and reload VS Code.',
    );
  }
  return extension.exports;
}

async function applyDefaultInterpreter(folder, notify = false) {
  const key = folder.uri.toString();
  if (applying.has(key)) return applying.get(key);

  const operation = (async () => {
    const executableUri = await resolveConfiguredInterpreter(folder);
    if (!executableUri) return;

    const api = await pythonEnvironmentsApi();
    await api.refreshEnvironments(undefined);
    const environment = await api.resolveEnvironment(executableUri);
    if (!environment) {
      throw new Error(`Python Environments could not resolve: ${executableUri.fsPath}`);
    }
    await api.setEnvironment(folder.uri, environment);
    output.appendLine(`${folder.uri.fsPath} -> ${executableUri.fsPath}`);
    if (notify) {
      vscode.window.showInformationMessage(`Python selected: ${executableUri.fsPath}`);
    }
  })();

  applying.set(key, operation);
  try {
    await operation;
  } finally {
    applying.delete(key);
  }
}

function report(error) {
  const message = error instanceof Error ? error.message : String(error);
  output.appendLine(`ERROR: ${message}`);
  vscode.window.showErrorMessage(`ZEMI Python: ${message}`);
}

function applyAll(notify = false) {
  for (const folder of vscode.workspace.workspaceFolders ?? []) {
    applyDefaultInterpreter(folder, notify).catch(report);
  }
}

function activate(context) {
  context.subscriptions.push(
    output,
    vscode.commands.registerCommand("zemiPython.applyDefaultInterpreter", () => applyAll(true)),
    vscode.workspace.onDidChangeConfiguration((event) => {
      if (event.affectsConfiguration("python.defaultInterpreterPath")) applyAll();
    }),
    vscode.workspace.onDidChangeWorkspaceFolders(() => applyAll()),
  );
  applyAll();
}

function deactivate() {}

module.exports = { activate, deactivate };
