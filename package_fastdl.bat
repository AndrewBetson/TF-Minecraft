@echo off
setlocal

set ROOT_DIR=%~dp0

cd game/tf/materials/models/minecraft/

for %%G in ( *.vmt *.vtf ) do (
	7z a -tbzip2 %%G.bz2 %%G
	robocopy . %ROOT_DIR%/fastdl/materials/models/minecraft/ %%G.bz2 /MOV
)

cd %ROOT_DIR%/game/tf/models/minecraft/

for %%G in ( *.* ) do (
	7z a -tbzip2 %%G.bz2 %%G
	robocopy . %ROOT_DIR%/fastdl/models/minecraft/ %%G.bz2 /MOV
)

cd %ROOT_DIR%/game/tf/sound/minecraft/

for %%G in ( *.mp3 ) do (
	7z a -tbzip2 %%G.bz2 %%G
	robocopy . %ROOT_DIR%/fastdl/sound/minecraft/ %%G.bz2 /MOV
)

endlocal
pause
