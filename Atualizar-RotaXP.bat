@echo off
setlocal
rem Atualiza o RotaXP com a versao mais nova do GitHub (substitui os arquivos desta pasta).
rem Suas configuracoes ficam na pasta WTF e NAO sao apagadas.
set "REPO=cleytoncl3/RotaXP"
set "DEST=%~dp0"
echo.
echo  RotaXP - atualizando a partir de https://github.com/%REPO%
echo  Pasta: %DEST%
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference = 'Stop';" ^
  "try {" ^
  "  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;" ^
  "  $tmp = Join-Path $env:TEMP ('RotaXP_' + [guid]::NewGuid().ToString('N'));" ^
  "  New-Item -ItemType Directory -Path $tmp | Out-Null;" ^
  "  $zip = Join-Path $tmp 'rotaxp.zip';" ^
  "  Write-Host ' Baixando...';" ^
  "  Invoke-WebRequest -UseBasicParsing -Uri 'https://github.com/%REPO%/archive/refs/heads/main.zip' -OutFile $zip;" ^
  "  Expand-Archive -Path $zip -DestinationPath $tmp -Force;" ^
  "  $src = Get-ChildItem -Path $tmp -Directory | Select-Object -First 1;" ^
  "  $old = (Select-String -Path (Join-Path $env:DEST 'RotaXP.toc') -Pattern '## Version: (.+)' -ErrorAction SilentlyContinue).Matches.Groups[1].Value;" ^
  "  $new = (Select-String -Path (Join-Path $src.FullName 'RotaXP.toc') -Pattern '## Version: (.+)').Matches.Groups[1].Value;" ^
  "  Write-Host (' Copiando arquivos (v' + $old + ' -> v' + $new + ')...');" ^
  "  Copy-Item -Path (Join-Path $src.FullName '*') -Destination $env:DEST -Recurse -Force;" ^
  "  Remove-Item -Path $tmp -Recurse -Force;" ^
  "  Write-Host '';" ^
  "  Write-Host (' Pronto! RotaXP v' + $new + ' instalado. Entre no jogo (ou digite /reload).') -ForegroundColor Green;" ^
  "} catch {" ^
  "  Write-Host '';" ^
  "  Write-Host (' Erro: ' + $_.Exception.Message) -ForegroundColor Red;" ^
  "  Write-Host ' Se o WoW estiver em Arquivos de Programas, clique com o botao direito no .bat e escolha Executar como administrador.';" ^
  "  exit 1" ^
  "}"
echo.
pause
