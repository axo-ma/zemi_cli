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
пропустить: созданный компонент содержит локальную настройку интерпретатора
`${workspaceFolder}/.venv/Scripts/python.exe`.

## 2. Создание экспериментального ZEMI Instance

На одной машине можно создать произвольное количество независимых ZEMI Instance.

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

Перейдите в каталог ZEMI Instance и запустите команду, указав имя каталога
нового компонента:

```powershell
zemi component create my_component
```

В процессе можно указать URL заранее созданного пустого Git-репозитория.  после чего комманда добавит его как новый `origin`.

Команда также создаёт локальный файл `@comp/.vscode/settings.json` и задаёт в
нём интерпретатор `${workspaceFolder}/.venv/Scripts/python.exe`. Настройка
начинает работать после создания окружения командой
`zemi component create-python-env`.

Команда не создаёт commit и не отправляет изменения автоматически. Сначала
проверьте и настройте компонент, затем сделайте commit и push удобным вам образом. Например, выполните обычные команды Git:

```powershell
git add -A
git commit -m "Initialize ZEMI component"
git push -u origin main
```

## 5. Создание Python-окружения компонента

После создания компонента перейдите в каталог ZEMI Component и выполните:

```powershell
zemi component create-python-env
```

Команда находит ZEMI Instance по маркеру над каталогом компонента и создаёт
`@comp/.venv` через интерпретатор
`@inst/_pythons/WPy64-312101/python/python.exe`.

Окружение создаётся с `--system-site-packages`: оно использует стандартную
библиотеку и все установленные пакеты базового WinPython. Дополнительные пакеты
можно устанавливать локально в `@comp/.venv`; локальные версии имеют приоритет.
Никакие зависимости проекта команда не устанавливает.

## 6. Включение Multi-root Workspace в VS Code

Из любого каталога внутри ZEMI Instance выполните:

```powershell
zemi vscode enable-multi-root
```

Закройте ваш VSCode и откройте в нем `@inst/ZEMI.code-workspace`.

Команда создаст VSCode workspace и поместит туда все zemi компоненты внутри текущего Zemi Instance.

Команда создаёт или обновляет файл `@inst/ZEMI.code-workspace`. В него входят
непосредственные дочерние каталоги Instance с одним из маркеров:

- `.zemicomp` — ZEMI Component;
- `.zemiworkroot` — дополнительный корень workspace, например `zemi` или
  `zemi_cli`.

Пути внутри workspace-файла относительны корня Instance. Повторный запуск
обновляет список каталогов и сохраняет остальные настройки workspace. 

