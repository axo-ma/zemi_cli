# Быстрая переустановка VS Code для ZEMI

Инструкция предназначена для Windows 10/11. Папки проектов, Git-репозитории,
WinPython и виртуальные окружения ZEMI удалять не нужно.

## 1. Полное удаление

Отключите Settings Sync, если он был включён, и закройте все окна VS Code.
Откройте отдельное окно PowerShell и выполните:

```powershell
Set-Location "C:\Users\Axoman\Documents\ZEMI\zemi_cli"
.\vscode_clean_uninstall.ps1 -WhatIf
.\vscode_clean_uninstall.ps1
```

Сначала просмотрите цели в режиме `-WhatIf`. При настоящем удалении введите
`DELETE`. Других подтверждений скрипт не запрашивает.

После завершения перезапустите Windows.

## 2. Получение официального установщика

Предпочтительный вариант — скачать **User Installer x64, Stable** с официальной
страницы:

<https://code.visualstudio.com/Download>

Прямая официальная ссылка на актуальный User Installer x64:

<https://code.visualstudio.com/sha/download?build=stable&os=win32-x64-user>

Скрипт проверяет цифровую подпись установщика Microsoft перед запуском.

Скачивать файл вручную необязательно: без параметра `-InstallerPath` скрипт
использует `winget` и пакет `Microsoft.VisualStudioCode`.

## 3. Быстрая установка

После перезапуска Windows откройте PowerShell и перейдите в `zemi_cli`:

```powershell
Set-Location "C:\Users\Axoman\Documents\ZEMI\zemi_cli"
```

Если установщик скачан вручную:

```powershell
.\vscode_quick_install.ps1 -InstallerPath "$env:USERPROFILE\Downloads\VSCodeUserSetup-x64.exe"
```

Замените имя файла фактическим именем скачанного установщика.

Если установщик не скачивали:

```powershell
.\vscode_quick_install.ps1
```

Скрипт устанавливает VS Code Stable и расширения:

- Microsoft Python (`ms-python.python`);
- Pylance (`ms-python.vscode-pylance`);
- Python Debugger (`ms-python.debugpy`);
- Python Environments (`ms-python.vscode-python-envs`);
- Jupyter (`ms-toolsai.jupyter`).

Скрипт не запускает и не настраивает VS Code, не изменяет пользовательский
`settings.json`, не добавляет ZEMI CLI в `PATH` терминала и не устанавливает
локальное расширение ZEMI Python Environment.

## 4. Проверка

Запустите VS Code вручную, затем:

1. Не включайте Settings Sync до окончания чистого теста.
2. Проверьте установленные Marketplace-расширения в панели Extensions.
3. Дальнейшую установку и проверку ZEMI выполняйте отдельно.
