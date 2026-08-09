# Путь разработчика: начало работы с ZEMI

## Prerequisites

До создания ZEMI Instance разработчик подготавливает рабочее место:

1. **Git** — обычная установка или portable-версия, на усмотрение разработчика.
2. **Visual Studio Code** — обычная установка или portable-версия.
3. Стандартные расширения VS Code:
   - Microsoft Python (`ms-python.python`);
   - Microsoft Jupyter (`ms-toolsai.jupyter`).
4. **7-Zip** — требуется для распаковки архива WinPython.
5. Доступ в интернет — для загрузки WinPython и клонирования репозитория.



## 1. Создание экспериментального ZEMI Instance

TODO: git clone zemi cli

Чтобы создать папку для Zemi Instance запуcтите:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
    -File .\create_zemi_instance.ps1
```

## 2. Загрузка WinPython 3.12

Запустите следующий скипт чтобы скачать WinPython:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
    -File .\download_winpython.ps1
```

Как альтернатива, можете скачать WinPython самостоятельно
[Winpython64-3.12.10.1slim.7z](https://github.com/winpython/winpython/releases/download/16.6.20250620final/Winpython64-3.12.10.1slim.7z)


Скрипт сохранит WinPython архив в `@inst/_tmp`. Распакуйте его с помощью 7-Zip в:

```text
@inst/_pythons
```

Проверьте интерпретатор:

```text
@inst/_pythons/WPy64-312101/python/python.exe --version
```

Ожидаемая версия: `Python 3.12.10`.

## 3. Сброс Python и Jupyter в VS Code

В дальнейшем предполагается что внутри VSCode доступны только одно python окружение, которое находится в папке .venv текущего проекта.

Если ваш VSCode прямо или косвенно был настроен на использвоание каких либо python сред, выполните сброс Python и Jupyter в VS Code, по инструкции ниже. Если VSCode не использовался раньше на вашей машине для работы с python, это шаг можно опустить 

Полностью закройте VS Code. Из внешнего PowerShell запустите одной строкой:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\reset_vscode_python.ps1 -InstancePath "<ZEMI Instance>"
```

Для portable VS Code добавьте `-UserDataPath "<VS Code>\data\user-data\User"`.

Скрипт очищает Python/Jupyter-настройки профиля VS Code и `.vscode` в деревьях
компонентов. Непосредственные служебные каталоги Instance с именем `_...` не
сканируются. `.venv`, WinPython, пакеты, ноутбуки и пользовательские kernelspec
не удаляются. Резервная копия не создаётся. После открытия проекта VS Code заново
обнаружит локальную `.venv`. Предложение установить Python через `uv` отключается.

## 4. Настройка ZEMI CLI внутри VS Code

ZEMI CLI может находиться в любом месте на диске. Чтобы его PowerShell-скрипты
были доступны во всех новых встроенных терминалах portable VS Code, сначала
запустите VS Code, затем выполните из каталога ZEMI CLI:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install_zemi_cli.ps1
```

Скрипт найдёт запущенный portable VS Code и добавит каталог ZEMI CLI только в
`terminal.integrated.env.windows.PATH` его пользовательских настроек. Windows
`PATH` не изменяется.

Закройте существующие встроенные терминалы VS Code и создайте новый терминал.
Проверьте доступность команд:

```powershell
Get-Command create_zemi_instance.ps1
Get-Command download_winpython.ps1
Get-Command configure_vscode_python.ps1
```

Каждая команда должна указывать на соответствующий файл в каталоге ZEMI CLI.

## 5. Создание ZEMI компонента из шаблона

