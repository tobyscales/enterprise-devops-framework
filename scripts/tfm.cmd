@echo off

set in_dir=%cd%
set config_dir=%~dp0..\
set _psrun=0
set _psinit=0
set tfargs=
REM TODO: IF NOT EXIST secrets.tfvars RUN INITIALIZE_DEVPC

for %%a in (.) do set currentfolder=%%~nxa
set subid=%currentfolder:~0,6%

if /i "%1"=="init" set _psinit=1

if /i "%1"=="plan" set _psrun=1
if /i "%1"=="apply" set _psrun=1
if /i "%1"=="destroy" set _psrun=1


if "%_psinit%"=="1" (
    pwsh -NoProfile -InputFormat None -ExecutionPolicy Bypass -file "%config_dir%tools\get-backend.ps1" 
    set tfargs=-backend-config=^"backend.tfvars^"
)

if "%_psrun%"=="1" (
    pwsh -NoProfile -InputFormat None -ExecutionPolicy Bypass -file "%config_dir%tools\get-config.ps1" 
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
            terraform %* -input=false %tfargs%
            popd 
        )
    )
)

rem delete-all config files for subscription-level deployments
del /Q /s "%in_dir%\backend.tfvars" >nul 2>&1
del /Q /s "%in_dir%\secrets.auto.tfvars" >nul
del /Q /s "%in_dir%\globals.auto.tfvars" >nul
del /Q /s "%in_dir%\provider.tf" >nul
del /Q /s "%in_dir%\*.pfx" >nul
