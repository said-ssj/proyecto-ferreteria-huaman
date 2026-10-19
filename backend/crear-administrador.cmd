@echo off
setlocal
pushd "%~dp0"
if not exist "target\ferreteria-huaman-admin.jar" (
 echo Primero compila el backend con mvnw.cmd package -Dbackend.artifact-name=ferreteria-huaman-admin.
 popd
 exit /b 1
)
java -jar "target\ferreteria-huaman-admin.jar" --spring.profiles.active=local,db,bootstrap-admin --server.address=127.0.0.1 --server.port=0
set "adminExitCode=%ERRORLEVEL%"
popd
exit /b %adminExitCode%
