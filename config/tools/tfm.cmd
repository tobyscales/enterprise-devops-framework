@echo off

set in_dir=%cd%
set config_dir=%~dp0..\
set _psrun=0
set _psinit=0
set tfargs=

rem TODO: support terragrunt-style "apply-all" deployments
for %%a in (.) do set currentfolder=%%~nxa
set subid=%currentfolder:~0,5%
echo %subid%|findstr /R /C:"\<[0123-9aAb-Cd-EfF][0123-9aAb-Cd-EfF][0123-9aAb-Cd-EfF][0123-9aAb-Cd-EfF][0123-9aAb-Cd-EfF]*" >nul
if %errorlevel% EQU 0 (
    echo *** Sorry, deploying from a subscription folder is not yet supported.
    goto :eof
    ) else (
        for %%a in (..) do set currentfolder=%%~nxa
    )
    set subid=%currentfolder:~0,5%

rem jump to the /config directory where the .cmd file lives
pushd "%config_dir%"


copy globals.tfvars "%in_dir%\globals.auto.tfvars" >nul
copy secrets.tfvars "%in_dir%\secrets.auto.tfvars" >nul
copy "%config_dir%certs\s%subid%.pfx" "%in_dir%" >nul
copy provider.tf "%in_dir%" >nul

rem return to the calling directory
popd 

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

terraform %* -input=false %tfargs%

del /Q "%in_dir%\backend.tfvars" >nul 2>&1
del /Q "%in_dir%\secrets.auto.tfvars" >nul
del /Q "%in_dir%\globals.auto.tfvars" >nul
del /Q "%in_dir%\provider.tf" >nul
del /Q "%in_dir%\*.pfx" >nul
