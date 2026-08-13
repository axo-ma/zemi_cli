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
6. Microsoft Office для работы с Excel.

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
.\zemi.cmd vscode install-cli
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
пропустить: команда создания компонента настроит интерпретатор автоматически.

## 2. Создание Zemi instance

На одной машине можно создать произвольное количество независимых ZEMI Instance.

Чтобы создать каталог для ZEMI Instance, запустите:

```powershell
zemi instance create
```

Команда создаст выбранный каталог ZEMI Instance и файл-маркер `.zemiinst_exp`
непосредственно в его корне.

Чтобы установить WinPython внутри созданного ZEMI Instance, перейдите в его
каталог и запустите:

```powershell
zemi instance deploy-winpython
```

Команда скачает архив WinPython в `@inst/_tmp` и предложит распаковать его в
`@inst/_pythons`.

Чтобы создать файл workspace для ZEMI Instance и настроить default Python venv,
запустите:

```powershell
zemi instance setup-vscode-workspace
```

Команда создаст default Python venv в `@inst/_venvs` и файл
`@inst/<имя-instance>.code-workspace`.

После завершения закройте VS Code, откройте
`@inst/<имя-instance>.code-workspace` и при запросе Workspace Trust подтвердите
доверие.

## 3. Создание ZEMI компонента

Чтобы создать ZEMI Component из шаблона, находясь внутри ZEMI Instance,
запустите:

```powershell
zemi component create my_component
```

Команда создаст каталог компонента с маркером `.zemicomp`, настроит использование
default Python venv и добавит компонент в workspace текущего ZEMI Instance.

При создании можно указать URL пустого Git-репозитория — он будет добавлен как
`origin`. Если удалённый репозиторий не нужен, оставьте URL пустым.

После создания вернитесь в VS Code и при запросе доверия к добавленному
компоненту нажмите **Yes**.

Проверьте созданный компонент, затем создайте первый commit средствами VS Code
или командами ниже. Если настроен `origin`, отправьте commit в удалённый
репозиторий:

```powershell
git add -A
git commit -m "Initialize ZEMI component"
git push -u origin main
```
