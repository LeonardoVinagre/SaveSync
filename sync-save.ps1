# Pasta de origem do save do jogo
$SaveDir = "C:\Users\leona\AppData\Local\R5\Saved\SaveProfiles\76561198045601166\RocksDB_v2\0.10.0\Worlds\5188C832831343B37E97EAAC28E205E0"

# Pasta raiz deste projeto
$ProjectDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Pastas do projeto
$SaveDest  = Join-Path $ProjectDir "save"
$BackupDir = Join-Path $ProjectDir "backup"

# --- Verificacoes iniciais ---
if (!(Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "ERRO: git nao encontrado no PATH"
    exit 1
}

Set-Location $ProjectDir

# ================================================================
# FASE 1: copiar save local para o projeto e tentar commitar
# ================================================================
if (Test-Path $SaveDir) {
    Write-Host "Copiando save local para o projeto..."

    if (!(Test-Path $SaveDest)) {
        New-Item -ItemType Directory -Path $SaveDest -Force | Out-Null
    }

    try {
        Copy-Item -Path "$SaveDir\*" -Destination $SaveDest -Recurse -Force -ErrorAction Stop
    } catch {
        Write-Host "ERRO: Falha ao copiar save para o projeto: $_"
        exit 1
    }

    git add save/

    git diff --cached --quiet
    $hasChanges = $LASTEXITCODE -ne 0

    if ($hasChanges) {
        $CommitMsg = "save: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        git commit -m $CommitMsg
        if ($LASTEXITCODE -ne 0) {
            Write-Host "ERRO: Commit falhou."
            exit 1
        }
        Write-Host "Commit realizado."

        git push
        if ($LASTEXITCODE -ne 0) {
            Write-Host "ERRO: Push falhou. Abortando para nao sobrescrever save local com versao antiga."
            exit 1
        }
        Write-Host "Push realizado com sucesso."
    } else {
        Write-Host "Nenhuma alteracao local detectada."
    }
} else {
    Write-Host "Pasta de save local nao encontrada, pulando upload."
}

# ================================================================
# FASE 2: pull, backup e atualizar destino
# ================================================================
Write-Host "Baixando save do GitHub..."
git pull
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERRO: git pull falhou."
    exit 1
}

if (!(Test-Path $SaveDest)) {
    Write-Host "ERRO: pasta save/ nao encontrada apos o pull."
    exit 1
}

# Backup do save atual antes de sobrescrever
if (Test-Path $SaveDir) {
    Write-Host "Fazendo backup do save atual..."
    if (!(Test-Path $BackupDir)) {
        New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
    }
    $Timestamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
    $BackupZip = Join-Path $BackupDir "backup_$Timestamp.zip"
    Compress-Archive -Path "$SaveDir\*" -DestinationPath $BackupZip -Force
    Write-Host "Backup salvo em $BackupZip"
}

Write-Host "Atualizando save em $SaveDir..."
if (!(Test-Path $SaveDir)) {
    New-Item -ItemType Directory -Path $SaveDir -Force | Out-Null
}

try {
    Copy-Item -Path "$SaveDest\*" -Destination $SaveDir -Recurse -Force -ErrorAction Stop
} catch {
    Write-Host "ERRO: Falha ao atualizar save do jogo: $_"
    Write-Host "O backup da execucao atual esta em: $BackupZip"
    exit 1
}
Write-Host "Save atualizado com sucesso!"
