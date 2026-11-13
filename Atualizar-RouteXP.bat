@echo off
setlocal
rem Atualiza o RouteXP com a versao mais nova do GitHub.
rem Instala sempre na pasta Interface\AddOns\RouteXP (ao lado desta pasta).
rem Suas configuracoes ficam na pasta WTF e NAO sao apagadas.
rem Se voce tinha o addon com o nome antigo (pasta RotaXP), ele copia suas configuracoes para o RouteXP
rem (pasta WTF) e apaga a pasta antiga. Rode com o jogo FECHADO.
set "REPO=cleytoncl3/RouteXP"
set "HERE=%~dp0"
for %%I in ("%HERE%..") do set "ADDONS=%%~fI"
set "DEST=%ADDONS%\RouteXP"
echo.
echo  RouteXP - atualizando a partir de https://github.com/%REPO%
echo  Pasta: %DEST%
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference = 'Stop';" ^
  "try {" ^
  "  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;" ^
  "  $tmp = Join-Path $env:TEMP ('RouteXP_' + [guid]::NewGuid().ToString('N'));" ^
  "  New-Item -ItemType Directory -Path $tmp | Out-Null;" ^
  "  $zip = Join-Path $tmp 'routexp.zip';" ^
  "  Write-Host ' Baixando...';" ^
  "  Invoke-WebRequest -UseBasicParsing -Uri 'https://github.com/%REPO%/archive/refs/heads/main.zip' -OutFile $zip;" ^
  "  Expand-Archive -Path $zip -DestinationPath $tmp -Force;" ^
  "  $src = Get-ChildItem -Path $tmp -Directory | Select-Object -First 1;" ^
  "  if (-not (Test-Path $env:DEST)) { New-Item -ItemType Directory -Path $env:DEST | Out-Null }" ^
  "  $oldToc = Join-Path $env:DEST 'RouteXP.toc'; $old = 'nenhuma';" ^
  "  if (Test-Path $oldToc) { $old = (Select-String -Path $oldToc -Pattern '## Version: (.+)').Matches.Groups[1].Value }" ^
  "  $new = (Select-String -Path (Join-Path $src.FullName 'RouteXP.toc') -Pattern '## Version: (.+)').Matches.Groups[1].Value;" ^
  "  Write-Host (' Copiando arquivos (v' + $old + ' -> v' + $new + ')...');" ^
  "  Copy-Item -Path (Join-Path $src.FullName '*') -Destination $env:DEST -Recurse -Force;" ^
  "  Remove-Item -Path (Join-Path $env:DEST 'RotaXP.toc') -Force -ErrorAction SilentlyContinue;" ^
  "  Remove-Item -Path (Join-Path $env:DEST 'Legacy.lua') -Force -ErrorAction SilentlyContinue;" ^
  "  Remove-Item -Path $tmp -Recurse -Force;" ^
  "  $wtf = Join-Path $env:ADDONS '..\..\WTF\Account';" ^
  "  $moved = 0;" ^
  "  if (Test-Path $wtf) { Get-ChildItem -Path $wtf -Recurse -Filter 'RotaXP.lua' -ErrorAction SilentlyContinue | Where-Object { $_.Directory.Name -eq 'SavedVariables' } | ForEach-Object { $to = Join-Path $_.DirectoryName 'RouteXP.lua'; if (-not (Test-Path $to)) { $t = [IO.File]::ReadAllText($_.FullName); $t = $t.Replace('RotaXPCharDB', 'RouteXPCharDB').Replace('RotaXPDB', 'RouteXPDB'); [IO.File]::WriteAllText($to, $t); $moved++ } } }" ^
  "  if ($moved -gt 0) { Write-Host (' Configuracoes do nome antigo (RotaXP) copiadas para o RouteXP: ' + $moved + ' arquivo(s).') }" ^
  "  Write-Host '';" ^
  "  Write-Host (' Pronto! RouteXP v' + $new + ' instalado em ' + $env:DEST) -ForegroundColor Green;" ^
  "} catch {" ^
  "  Write-Host '';" ^
  "  Write-Host (' Erro: ' + $_.Exception.Message) -ForegroundColor Red;" ^
  "  Write-Host ' Se o WoW estiver em Arquivos de Programas, clique com o botao direito no .bat e escolha Executar como administrador.';" ^
  "  exit 1" ^
  "}"
set "OK=%ERRORLEVEL%"
echo.
rem pasta antiga RotaXP (nome velho): apagada depois que este .bat fecha, se a instalacao deu certo
set "OLD=%ADDONS%\RotaXP"
if "%OK%"=="0" if exist "%OLD%\RotaXP.toc" if not exist "%OLD%\.git" (
  echo  A pasta antiga RotaXP sera apagada: o addon agora fica so na pasta RouteXP.
  echo.
  pause
  start "" /min powershell -NoProfile -WindowStyle Hidden -Command "Start-Sleep 2; Remove-Item -LiteralPath '%OLD%' -Recurse -Force"
  exit /b 0
)
pause
