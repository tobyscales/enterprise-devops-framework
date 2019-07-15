@echo off

set in_dir=%cd%
set root_dir=%~dp0..\
set _psrun=0
set _psinit=0
set tfargs=
REM TODO: IF NOT EXIST secrets.tfvars RUN INITIALIZE_DEVPC

for %%a in (.) do set currentfolder=%%~nxa
set subid=%currentfolder:~0,6%

rem Fix this to allow for running in rg folders
:: echo %subid%|findstr /R /C:"\<[s][0123-9aAb-Cd-EfF][0123-9aAb-Cd-EfF][0123-9aAb-Cd-EfF][0123-9aAb-Cd-EfF][0123-9aAb-Cd-EfF]*" >nul
:: if %errorlevel% NEQ 0 goto err_path


if /i "%1"=="" goto help
if /i "%1"=="init" set _psinit=1

if /i "%1"=="plan" set _psrun=1
if /i "%1"=="apply" set _psrun=1
if /i "%1"=="destroy" set _psrun=1

if "%_psinit%"=="1" (
    pwsh -NoProfile -NoLogo -NonInteractive -ExecutionPolicy Bypass -file "%root_dir%scripts\get-backend.ps1"
    if errorlevel == 1 goto cleanup
    set tfargs=-backend-config=^"backend.tfvars^"
)

if "%_psrun%"=="1" (
    pwsh -NoProfile -ExecutionPolicy Bypass -file "%root_dir%scripts\get-config.ps1" 
    if errorlevel == 1 goto cleanup
)

rem .terraform directory exclusion code cribbed from https://stackoverflow.com/posts/25539569/revisions
for /R "%in_dir%" %%G in (.) DO (
    echo %%G | find /i ".terraform" >nul && ( 
        echo %%G >nul
    ) || (
        pushd %%G
        if "%%G"=="%in_dir%\." ( 
            echo >nul 
        ) else (
            terraform %* %tfargs%
            popd 
        )
    )
)

goto :cleanup

:help
terraform /? 2>nul
if %errorlevel% NEQ 127 echo ***** ERROR ***** & echo.  Is terraform in your path? & echo ***** ERROR *****
goto :eof

:cleanup
rem delete-all config files for subscription-level deployments
del /Q /s "%in_dir%\backend.tfvars" >nul 2>&1
del /Q /s "%in_dir%\secrets.auto.tfvars" >nul 2>&1
del /Q /s "%in_dir%\globals.auto.tfvars" >nul 2>&1
del /Q /s "%in_dir%\provider.tf" >nul 2>&1
del /Q /s "%in_dir%\*.pfx" >nul 2>&1
goto :eof

:err_path
echo You must run tfm.cmd from a path below the /live directory.

:eof