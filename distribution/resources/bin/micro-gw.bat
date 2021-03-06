@echo off
REM ---------------------------------------------------------------------------
REM  Copyright (c) 2018, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
REM
REM  Licensed under the Apache License, Version 2.0 (the "License");
REM  you may not use this file except in compliance with the License.
REM  You may obtain a copy of the License at
REM
REM  http://www.apache.org/licenses/LICENSE-2.0
REM
REM  Unless required by applicable law or agreed to in writing, software
REM  distributed under the License is distributed on an "AS IS" BASIS,
REM  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
REM  See the License for the specific language governing permissions and
REM  limitations under the License.

REM ----------------------------------------------------------------------------
REM Startup Script for Gateway Cli
REM
REM Environment Variable Prerequisites
REM
REM   BALLERINA_HOME      Home of Ballerina installation.
REM
REM   JAVA_HOME           Must point at your Java Development Kit installation.
REM
REM   JAVA_OPTS           (Optional) Java runtime options used when the commands
REM                       is executed.
REM
REM NOTE: Borrowed generously from Apache Tomcat startup scripts.
REM -----------------------------------------------------------------------------
SETLOCAL EnableDelayedExpansion

if ""%1%""==""--verbose"" ( SET verbose=T ) else ( SET verbose=F )
if %verbose%==T ( ECHO Verbose mode enabled )

REM Get the location of this(micro-gw.bat) file
SET PRGDIR=%~sdp0
SET CURRENT_D=%CD%

REM If the current disk drive ie: `E:\` is different from the drive where this (micro-gw.bat) resides(i:e `C:\`), Change the driver label the current drive
:switchDrive
	SET curDrive=%CURRENT_D:~0,1%
	SET wsasDrive=%PRGDIR:~0,1%
	if %verbose%==T ( ECHO Switch to drive '%wsasDrive%' if current drive '%curDrive%' not equal to program drive '%wsasDrive%' )
	if NOT "%curDrive%" == "%wsasDrive%" %wsasDrive%:

REM if MICROGW_HOME environment variable not set then set it
if "%MICROGW_HOME%" == "" SET MICROGW_HOME=%PRGDIR%..

REM set BALLERINA_HOME
SET BALLERINA_HOME=%MICROGW_HOME%\lib\platform
if NOT EXIST %BALLERINA_HOME% SET BALLERINA_HOME="%MICROGW_HOME%\lib"

SET PATH=%PATH%;%BALLERINA_HOME%\bin\
if %verbose%==T ECHO BALLERINA_HOME environment variable is set to %BALLERINA_HOME%
if %verbose%==T ECHO MICROGW_HOME environment variable is set to %MICROGW_HOME%

REM Check JAVA availability
:checkJavaHome
	if "%JAVA_HOME%" == "" goto noJavaHome
	if NOT EXIST "%JAVA_HOME%\bin\java.exe" goto noJavaHome
goto checkJava

:noJavaHome
	ECHO "You must set the JAVA_HOME variable before running Micro-Gateway Tooling."
goto end

:checkJava
	"%JAVA_HOME%\bin\java" -version >nul 2>&1
	IF ERRORLEVEL 1 goto noJava
goto runServer

:noJava
	ECHO Error: JAVA_HOME is not defined correctly.
goto end

:runServer
	if %verbose%==T ECHO JAVA_HOME environment variable was set to %JAVA_HOME%
	SET originalArgs=%*
	if ""%1""=="""" goto usageInfo

REM Slurp the command line arguments. This loop allows for an unlimited number
REM of arguments (up to the command line limit, anyway).
:setupArgs
	if %verbose%==T ECHO Processing argument : `%1`
	if ""%1""=="""" goto passToJar
	if ""%1""==""help""     goto passToJar
	if ""%1""==""build""     goto commandBuild
	if ""%1""==""--java.debug""  goto commandDebug
	SHIFT
goto setupArgs

:usageInfo
	ECHO Missing command operand
	ECHO "Use: micro-gw [--verbose] (init | import | build)"
goto :end

:commandBuild
	if %verbose%==T ECHO Running commandBuild

	REM Immediate next parameter should be project name after the `build` command
	SHIFT
	SET "project_name=%1"
	if [%project_name%] == [] ( goto :noName ) else ( goto :nameFound )

	:noName
		ECHO "micro-gw: main parameters are required (""), Run 'micro-gw help' for usage."
		goto :usageInfo

	:nameFound
		if %verbose%==T ECHO Building micro gateway for project %project_name:\=%

		REM Set micro gateway project directory relative to CD (current directory)
		SET MICRO_GW_PROJECT_DIR="%CURRENT_D%\%project_name:\=%"
		if EXIST %MICRO_GW_PROJECT_DIR% goto :continueBuild
			REM Exit, if can not find a project with given project name
			if %verbose%==T ECHO Project directory does not exist for given name %MICRO_GW_PROJECT_DIR%
			ECHO "Incorrect project name `%project_name:\=%` or Workspace not initialized, Run setup befor building the project!"
			goto :EOF

		if ERRORLEVEL 1 goto :end

        :continueBuild
            call :passToJar
            REM set ballerina home again as the platform is extracted at this point.
            SET BALLERINA_HOME=%MICROGW_HOME%\lib\platform
            SET PATH=%PATH%;%BALLERINA_HOME%\bin\
            if %verbose%==T ECHO BALLERINA_HOME environment variable is set to %BALLERINA_HOME%
            ECHO MICRO_GW_PROJECT_DIR:  "%CURRENT_D%"
            PUSHD "%CURRENT_D%"
            PUSHD "%MICRO_GW_PROJECT_DIR%\target\gen"
                if %verbose%==T ECHO current dir %CD%
                SET TARGET_DIR="%MICRO_GW_PROJECT_DIR%\target"
                if EXIST "%TARGET_DIR%\*.balx"  DEL /F "%TARGET_DIR%\*.balx"
                call ballerina build src -o %TARGET_DIR%\%project_name:\=%.balx --offline --experimental --siddhiruntime
            POPD

            if %verbose%==T ECHO Ballerina build completed
            SET originalArgs=%originalArgs% --compiled

            REM Check for a debug param by looping through the remaining args list
            :checkDebug
                SHIFT
                if ""%1""=="""" goto passToJar
                if ""%1""==""--java.debug""  goto commandDebug
            goto checkDebug
goto :passToJar

:commandDebug
	if %verbose%==T ECHO Running commandDebug

	SHIFT
	SET DEBUG_PORT=%1
	if "%DEBUG_PORT%"=="" goto noDebugPort
	if NOT "%JAVA_OPTS%"=="" ECHO Warning !!!. User specified JAVA_OPTS will be ignored, once you give the --java.debug option.
	SET JAVA_OPTS=-Xdebug -Xnoagent -Djava.compiler=NONE -Xrunjdwp:transport=dt_socket,server=y,suspend=y,address=%DEBUG_PORT%
	ECHO Please start the remote debugging client to continue...
goto passToJar

:noDebugPort
	ECHO Please specify the debug port after the --java.debug option
goto end


:passToJar
	REM ---------- Add jars to classpath ----------------
	if %verbose%==T echo Running passToJar
	SET CLI_CLASSPATH=
	if EXIST "%BALLERINA_HOME%"\bre\lib (
		for %%i in ("%BALLERINA_HOME%"\bre\lib\*.jar) do (
			SET CLI_CLASSPATH=!CLI_CLASSPATH!;.\lib\platform\bre\lib\%%~ni%%~xi
		)
	) else (
		REM Ballerina platform is not extracted yet.
		REM Therefore we need to set cli init jars to the classpath
		REM Platform will be extracted during the execution of Init Command
		for %%i IN ("%MICROGW_HOME%"\lib\gateway\platform\*.jar) do (
			SET CLI_CLASSPATH=!CLI_CLASSPATH!;.\lib\gateway\platform\%%~ni%%~xi
		)
		for %%i IN ("%MICROGW_HOME%"\lib\gateway\cli\*.jar) do (
			SET CLI_CLASSPATH=!CLI_CLASSPATH!;.\lib\gateway\cli\%%~ni%%~xi
		)
	)

	if %verbose%==T ECHO CLI_CLASSPATH = "%CLI_CLASSPATH%"

	SET JAVACMD=-Xms256m -Xmx1024m ^
		-XX:+HeapDumpOnOutOfMemoryError ^
		-XX:HeapDumpPath="%MICROGW_HOME%\heap-dump.hprof" ^
		%JAVA_OPTS% ^
		-classpath %CLI_CLASSPATH% ^
		-Djava.security.egd=file:/dev/./urandom ^
		-Dballerina.home="%BALLERINA_HOME%" ^
		-Djava.util.logging.config.class="org.wso2.apimgt.gateway.cli.logging.CLILogConfigReader" ^
		-Djava.util.logging.manager="org.wso2.apimgt.gateway.cli.logging.CLILogManager" ^
		-Dfile.encoding=UTF8 ^
		-Dtemplates.dir.path="%MICROGW_HOME%"\resources\templates ^
		-Dcli.home="%MICROGW_HOME%" ^
		-Dcurrent.dir="%CD%" ^
		-DVERBOSE_ENABLED=%verbose%
	if %verbose%==T ECHO JAVACMD = !JAVACMD!

:runJava
	REM Jump to GW-CLI exec location when running the jar
	CD %MICROGW_HOME%
	"%JAVA_HOME%\bin\java" %JAVACMD% org.wso2.apimgt.gateway.cli.cmd.Main %originalArgs%
	if "%ERRORLEVEL%"=="121" goto runJava
	if ERRORLEVEL 1 goto :end
:end
goto endlocal

:endlocal

:END
