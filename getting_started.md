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

> **Обозначение `@inst`.** В этом руководстве `@inst` означает путь к корню
> конкретного ZEMI Instance. Это не буквальное имя каталога. Например, если
> Instance находится в `D:\ZEMI\experiment-01`, то `@inst/_tmp` означает
> `D:\ZEMI\experiment-01\_tmp`.



## 1. Развёртывание ZEMI CLI

Выберите любое место на диске и клонируйте репозиторий ZEMI CLI:

```powershell
git clone https://github.com/axo-ma/zemi_cli.git
cd .\zemi_cli
```

Запустите VS Code. Должна быть открыта только одна установка VS Code. Затем из
каталога ZEMI CLI выполните:

```powershell
.\zemi.cmd cli install
```

Команда добавит каталог ZEMI CLI только в `terminal.integrated.env.windows.PATH` пользовательских настроек VS Code.


Закройте существующие встроенные терминалы VS Code и создайте новый терминал.
Проверьте глобальную команду:

```powershell
zemi hello
```

Ожидаемый результат:

```text
Hello from ZEMI!
```

Посмотреть доступные команды можно через `zemi help`.

Если VS Code раньше использовал другие Python-окружения или ядра Jupyter,
сбросьте старые настройки:

```powershell
zemi vscode reset-python-settings
```

После команды перезапустите VS Code. Для новой установки этот шаг можно
пропустить: VS Code самостоятельно обнаружит единственную `.venv` в корне
компонента.

## 2. Создание экспериментального ZEMI Instance

На одной машине можно создать произвольное количество независимых ZEMI Instance.
Для каждого нового Instance повторно выполните команду создания и выберите
отдельный корневой каталог.

Чтобы создать каталог ZEMI Instance, запустите:

```powershell
zemi instance create
```

## 3. Загрузка WinPython 3.12

Чтобы скачать WinPython, запустите:

```powershell
zemi winpython download
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

## 4. Создание ZEMI компонента из шаблона
