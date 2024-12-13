@echo off
setlocal enabledelayedexpansion

REM *********************************************************************************************
REM This script installs ProActive nodes on a Windows machine. Prerequisites include:
REM - Administrator privileges to execute commands like creating directories, managing services, etc.
REM - (For an online installation) Internet access to be able to download the required NSSM and ProActive node archives.
REM - (For an offline installation) Local copies of NSSM and ProActive node archive.
REM - A 'keys' directory containing the public/private SSH keys and 'rm.cred' file from the ProActive server.
REM - Pre-configured node source in the RM portal with static policy and default infrastructure.
REM Ensure all paths and variables below are correctly set before running the script.
REM *********************************************************************************************


REM Set input variables

REM HTTPS URL or absolute local path to the NSSM archive.
REM Use an HTTPS URL if you have internet access, otherwise an absolute local path to the NSSM archive.
set NSSM_ZIP_LOCATION=https://nssm.cc/release/nssm-2.24.zip

REM HTTPS URL or absolute local path to the ProActive node archive.
REM Use an HTTPS URL if you have internet access, otherwise an absolute local path to the ProActive node archive
set PROACTIVE_NODE_ZIP_LOCATION=HTTPS_URL_OR_ABSOLUTE_LOCAL_PATH

REM Absolute local path to the directory where the ProActive node will be installed.
REM This directory will be created by the script if it doesn't already exist.
set INSTALLATION_DIRECTORY=C:\proactive

REM Use the built-in LocalSystem account to run the 'proactive-node' service
set SERVICE_USE_LOCAL_SYSTEM_ACCOUNT=true

REM The username of the account under which the service 'proactive-node' will be executed
REM The 'SERVICE_USER_NAME' property is ignored if SERVICE_USE_LOCAL_SYSTEM_ACCOUNT=true
set SERVICE_USER_NAME=DOMAIN\USERNAME

REM The password associated with the service user account
REM The 'SERVICE_USER_PASSWORD' property is ignored if SERVICE_USE_LOCAL_SYSTEM_ACCOUNT=true
set SERVICE_USER_PASSWORD=PASSWORD

REM Absolute local path to the 'keys' directory.
REM Create a directory named 'keys' and add the following files from the ProActive server:
REM - Public/private key pair from the ProActive server's SSH folder (e.g., located in ~/.ssh/).
REM - The 'rm.cred' file from '<Server_Installation_Directory>/config/authentication/' for node authentication.
REM Once these files are added to the 'keys' directory, specify its path below.
set NODE_SOURCE_KEYS_LOCATION=ABSOLUTE_LOCAL_PATH_TO_KEYS_DIRECTORY

REM Name of the Windows node source.
REM In the RM portal, create an empty node source with default infrastructure and static policy.
REM Once the node source is created, provide its name below.
set NODE_SOURCE_NAME=Windows-Nodes

REM Number of Windows nodes to be added to the node source.
set NODE_SOURCE_NUMBER_OF_NODES=2

REM Resource Manager (RM) URL. Default is pamr://0.
set NODE_SOURCE_RM_URL=pamr://0

REM Communication protocol used by ProActive. Default is pamr.
set NODE_SOURCE_COMMUNICATION_PROTOCOL=pamr

REM Router address of the ProActive server.
set NODE_SOURCE_ROUTER_ADDRESS=SCHEDULER_SERVER_DNS_OR_IP

REM SSH username for ProActive server.
set NODE_SOURCE_SSH_USERNAME=SCHEDULER_SSH_USERNAME


REM *********************************************************************************************
REM Check if proactive-node service is already running, then stop and remove it
sc query proactive-node >nul 2>&1
if %errorlevel% equ 0 (
    REM Service exists, stop it and remove it
    echo Stopping proactive-node service...
    %INSTALLATION_DIRECTORY%\nssm-2.24\win64\nssm.exe stop proactive-node
    if %errorlevel% neq 0 (
        echo Failed to stop proactive-node service. Exiting.
        exit /b 1
    )
    echo Removing proactive-node service...
    %INSTALLATION_DIRECTORY%\nssm-2.24\win64\nssm.exe remove proactive-node confirm
    if %errorlevel% neq 0 (
        echo Failed to remove proactive-node service. Exiting.
        exit /b 1
    )
) else (
    REM Service does not exist
    echo The proactive-node service does not exist.
)

REM *********************************************************************************************
REM Handle the installation directory
if exist "%INSTALLATION_DIRECTORY%" (
    echo Directory exists. Attempting to remove it...
    set RETRY_COUNT=0
    :RetryRemove
    rmdir /s /q "%INSTALLATION_DIRECTORY%"
    if %errorlevel% neq 0 (
        set /a RETRY_COUNT+=1
        timeout /t 1 >nul
        if !RETRY_COUNT! lss 3 goto :RetryRemove
        echo Failed to remove directory after multiple attempts. Exiting.
        exit /b 1
    ) else (
        echo Directory removed successfully.
    )
) else (
    echo Directory does not exist. Creating it...
)
echo Creating the installation directory...
mkdir "%INSTALLATION_DIRECTORY%"
if %errorlevel% neq 0 (
    echo Failed to create installation directory. Exiting.
    exit /b 1
)

REM *********************************************************************************************
REM Handle PROACTIVE_NODE_ZIP_LOCATION
echo Checking PROACTIVE_NODE_ZIP_LOCATION...
echo %PROACTIVE_NODE_ZIP_LOCATION% | findstr /i "^http:// ^https://" >nul
if %errorlevel%==0 (
    REM URL is valid, download the file
    echo Downloading from URL: %PROACTIVE_NODE_ZIP_LOCATION%
    curl -k -o "%INSTALLATION_DIRECTORY%\activeeon-windows-node-x64.zip" "%PROACTIVE_NODE_ZIP_LOCATION%"
    if %errorlevel% neq 0 (
        echo Failed to download PROACTIVE_NODE_ZIP. Exiting.
        exit /b 1
    )
) else (
    REM Copy local file
    echo Copying local file: %PROACTIVE_NODE_ZIP_LOCATION%
    copy "%PROACTIVE_NODE_ZIP_LOCATION%" "%INSTALLATION_DIRECTORY%\activeeon-windows-node-x64.zip"
)

REM *********************************************************************************************
REM Handle NSSM_ZIP_LOCATION
echo Checking NSSM_ZIP_LOCATION...
echo %NSSM_ZIP_LOCATION% | findstr /i "^http:// ^https://" >nul
if %errorlevel%==0 (
    REM URL is valid, download the file
    echo Downloading from URL: %NSSM_ZIP_LOCATION%
    curl -k -o "%INSTALLATION_DIRECTORY%\nssm-2.24.zip" "%NSSM_ZIP_LOCATION%"
    if %errorlevel% neq 0 (
        echo Failed to download NSSM_ZIP. Exiting.
        exit /b 1
    )
) else (
    REM Copy local file
    echo Copying local file: %NSSM_ZIP_LOCATION%
    copy "%NSSM_ZIP_LOCATION%" "%INSTALLATION_DIRECTORY%\nssm-2.24.zip"
)

REM *********************************************************************************************
REM Extract both ZIP files
echo Extracting PROACTIVE_NODE_ZIP...
powershell -Command "Expand-Archive -Path '%INSTALLATION_DIRECTORY%\activeeon-windows-node-x64.zip' -DestinationPath '%INSTALLATION_DIRECTORY%'"
if %errorlevel% neq 0 (
    echo Failed to extract PROACTIVE_NODE_ZIP. Exiting.
    exit /b 1
)

echo Extracting NSSM_ZIP...
powershell -Command "Expand-Archive -Path '%INSTALLATION_DIRECTORY%\nssm-2.24.zip' -DestinationPath '%INSTALLATION_DIRECTORY%'"
if %errorlevel% neq 0 (
    echo Failed to extract NSSM_ZIP. Exiting.
    exit /b 1
)
echo All files downloaded and extracted successfully.

REM *********************************************************************************************
REM Set PROACTIVE_NODE_FOLDER variable to the folder starting with 'activeeon' in %INSTALLATION_DIRECTORY%
for /d %%F in ("%INSTALLATION_DIRECTORY%\activeeon*") do set "PROACTIVE_NODE_FOLDER=%%~nxF" & goto :FoundProActive

:FoundProActive
if defined PROACTIVE_NODE_FOLDER (
    echo Found folder: %PROACTIVE_NODE_FOLDER%
) else (
    echo No folder starting with 'activeeon' found in %INSTALLATION_DIRECTORY%. Exiting.
    exit /b 1
)
set PROACTIVE_NODE_FOLDER_PATH=%INSTALLATION_DIRECTORY%\%PROACTIVE_NODE_FOLDER%

REM *********************************************************************************************
REM Copy input keys (priv key, public key, rm.cred) to the %INSTALLATION_DIRECTORY%
Xcopy /E /I %NODE_SOURCE_KEYS_LOCATION% %INSTALLATION_DIRECTORY%\keys /Y
if %errorlevel% neq 0 (
    echo Failed to copy input keys. Exiting.
    exit /b 1
)

REM *********************************************************************************************
REM Update PATH if NSSM_DIR is not already included
set NSSM_DIR=%INSTALLATION_DIRECTORY%\nssm-2.24\win64
set PATH=%PATH%;%NSSM_DIR%

REM *********************************************************************************************
REM NSSM service configuration
nssm.exe install proactive-node "%PROACTIVE_NODE_FOLDER_PATH%\bin\proactive-node.bat"
if %errorlevel% neq 0 (
    echo Failed to install proactive-node service. Exiting.
    exit /b 1
)

nssm.exe set proactive-node AppParameters "-r %NODE_SOURCE_RM_URL% -w %NODE_SOURCE_NUMBER_OF_NODES% -s %NODE_SOURCE_NAME% -f \"%INSTALLATION_DIRECTORY%\keys\rm.cred\" -Dproactive.communication.protocol=%NODE_SOURCE_COMMUNICATION_PROTOCOL% -Dproactive.pamr.socketfactory=ssh -Dproactive.pamr.router.address=%NODE_SOURCE_ROUTER_ADDRESS% -Dproactive.pamrssh.username=%NODE_SOURCE_SSH_USERNAME% \"-Dproactive.pamrssh.key_directory=%INSTALLATION_DIRECTORY%\keys\""
if %errorlevel% neq 0 (
    echo Failed to set AppParameters. Exiting.
    exit /b 1
)

nssm.exe set proactive-node AppDirectory "%PROACTIVE_NODE_FOLDER_PATH%\bin"
if %errorlevel% neq 0 (
    echo Failed to set AppDirectory. Exiting.
    exit /b 1
)

if "%SERVICE_USE_LOCAL_SYSTEM_ACCOUNT%" == "true" (
    nssm.exe set proactive-node ObjectName "LocalSystem"
    if %errorlevel% neq 0 (
        echo Failed to set ObjectName. Exiting.
        exit /b 1
    )
) else (
    nssm.exe set proactive-node ObjectName "%SERVICE_USER_NAME%" "%SERVICE_USER_PASSWORD%"
    if %errorlevel% neq 0 (
        echo Failed to set ObjectName. Exiting.
        exit /b 1
    )
)

nssm.exe set proactive-node AppStdout "%PROACTIVE_NODE_FOLDER_PATH%\node.out"
if %errorlevel% neq 0 (
    echo Failed to set AppStdout. Exiting.
    exit /b 1
)

nssm.exe set proactive-node AppStderr "%PROACTIVE_NODE_FOLDER_PATH%\node.out"
if %errorlevel% neq 0 (
    echo Failed to set AppStderr. Exiting.
    exit /b 1
)

nssm.exe start proactive-node
if %errorlevel% neq 0 (
    echo Failed to start proactive-node service. Exiting.
    exit /b 1
)

echo ProActive Nodes installation completed successfully.
echo For more details, check logs in %PROACTIVE_NODE_FOLDER_PATH%.