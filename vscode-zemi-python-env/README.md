# ZEMI Python Environment

Automatically makes the project value of `python.defaultInterpreterPath` the
active Python environment in VS Code. There is no environment picker and no
additional ZEMI setting.

Example project setting:

```json
{
  "python.defaultInterpreterPath": "C:/ZEMI/_venvs/shared/Scripts/python.exe"
}
```

`${workspaceFolder}`, `${workspaceFolder:name}`, `${workspaceFolderBasename}`,
and `${env:NAME}` variables are supported. The configured value may point to a
Python executable or to an environment directory.

The setting is applied when VS Code starts, when workspace folders change, and
whenever `python.defaultInterpreterPath` changes. To force it manually, run
`ZEMI: Apply Project Default Python Interpreter`.
