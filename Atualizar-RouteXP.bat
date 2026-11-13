@echo off
setlocal
rem Atualiza o RouteXP com a versao mais nova do GitHub.
rem Instala sempre na pasta Interface\AddOns\RouteXP (ao lado desta pasta).
rem Suas configuracoes ficam na pasta WTF e NAO sao apagadas.
rem Se voce tinha o addon com o nome antigo (pasta RotaXP), entre no jogo uma vez com as duas pastas:
rem o RouteXP copia sozinho as configuracoes e o progresso da antiga. Depois pode apagar a pasta RotaXP.
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
  "  $old = (Select-String -Path (Join-Path $env:DEST 'RouteXP.toc') -Pattern '## Version: (.+)' -ErrorAction SilentlyContinue).Matches.Groups[1].Value;" ^
  "  $new = (Select-String -Path (Join-Path $src.FullName 'RouteXP.toc') -Pattern '## Version: (.+)').Matches.Groups[1].Value;" ^
  "  Write-Host (' Copiando arquivos (v' + $old + ' -> v' + $new + ')...');" ^
  "  Copy-Item -Path (Join-Path $src.FullName '*') -Destination $env:DEST -Recurse -Force;" ^
  "  Remove-Item -Path (Join-Path $env:DEST 'RotaXP.toc') -Force -ErrorAction SilentlyContinue;" ^
  "  Remove-Item -Path $tmp -Recurse -Force;" ^
  "  Write-Host '';" ^
  "  Write-Host (' Pronto! RouteXP v' + $new + ' instalado em ' + $env:DEST) -ForegroundColor Green;" ^
  "  if (Test-Path (Join-Path $env:ADDONS 'RotaXP')) { Write-Host ' Voce ainda tem a pasta antiga RotaXP: entre no jogo uma vez (o RouteXP copia suas configuracoes) e depois apague a pasta RotaXP.' -ForegroundColor Yellow }" ^
  "} catch {" ^
  "  Write-Host '';" ^
  "  Write-Host (' Erro: ' + $_.Exception.Message) -ForegroundColor Red;" ^
  "  Write-Host ' Se o WoW estiver em Arquivos de Programas, clique com o botao direito no .bat e escolha Executar como administrador.';" ^
  "  exit 1" ^
  "}"
echo.
pause
