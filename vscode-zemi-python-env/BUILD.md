# Building the VS Code extension

The extension is plain JavaScript, so it does not require a compilation step.
Building means validating and packaging the project as a `.vsix` file.

## Prerequisites

- Node.js with `npm` and `npx` available on `PATH`.
- Internet access the first time `npx` downloads `@vscode/vsce`.

## Package

Run these commands from this extension directory:

```powershell
New-Item -ItemType Directory -Path dist -Force | Out-Null
npx @vscode/vsce package --out dist/zemi-python-environment-0.1.1.vsix
```

`vsce` reads `package.json`, applies `.vscodeignore`, validates the extension
metadata, and creates the installable VSIX package.

When the version in `package.json` changes, use the same version in the output
file name.

## Install the local build

```powershell
code --install-extension dist/zemi-python-environment-0.1.1.vsix --force
```

Then run `Developer: Reload Window` in VS Code.

## Development run

Open this extension directory in VS Code and press `F5`. The included
`.vscode/launch.json` starts an Extension Development Host without packaging.
