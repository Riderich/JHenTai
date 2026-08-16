param(
    [Parameter(Mandatory = $true)][string]$RuntimeRoot,
    [Parameter(Mandatory = $true)][string]$BundleRoot,
    [string]$UseCuda = 'false'
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Report([int]$Progress, [string]$Message) {
    Write-Output "JHENTAI_STATUS|$Progress|$Message"
}

New-Item -ItemType Directory -Force -Path $RuntimeRoot | Out-Null
$pythonRoot = Join-Path $RuntimeRoot 'python'
$pythonExe = Join-Path $pythonRoot 'python.exe'
$installer = Join-Path $RuntimeRoot 'python-3.11.9-amd64.exe'
$engineRoot = Join-Path $RuntimeRoot 'engine'
$adapterRoot = Join-Path $RuntimeRoot 'adapter'
$venvRoot = Join-Path $RuntimeRoot 'venv'
$venvPython = Join-Path $venvRoot 'Scripts\python.exe'

if (-not (Test-Path $pythonExe)) {
    Report 5 '正在下载 Python 3.11（约 26 MB）'
    if (-not (Test-Path $installer)) {
        Invoke-WebRequest 'https://www.python.org/ftp/python/3.11.9/python-3.11.9-amd64.exe' -OutFile $installer
    }
    Report 12 '正在安装独立 Python 环境'
    $process = Start-Process -FilePath $installer -ArgumentList @(
        '/quiet', 'InstallAllUsers=0', 'Include_launcher=0', 'Include_test=0',
        'Include_tcltk=0', 'Include_pip=1', 'PrependPath=0', "TargetDir=$pythonRoot"
    ) -Wait -PassThru -WindowStyle Hidden
    if ($process.ExitCode -ne 0 -or -not (Test-Path $pythonExe)) {
        throw "Python 安装失败（退出代码 $($process.ExitCode)）"
    }
}

$bundledEngine = Join-Path $BundleRoot 'translation_engine'
$bundledAdapter = Join-Path $BundleRoot 'translation_service'
if (-not (Test-Path (Join-Path $bundledEngine 'manga_translator'))) {
    throw '测试包缺少 translation_engine 目录，请重新下载完整压缩包并全部解压'
}

Report 20 '正在准备漫画翻译引擎'
if (-not (Test-Path (Join-Path $engineRoot '.jhentai-engine'))) {
    if (Test-Path $engineRoot) { Remove-Item -LiteralPath $engineRoot -Recurse -Force }
    Copy-Item -LiteralPath $bundledEngine -Destination $engineRoot -Recurse
    New-Item -ItemType File -Path (Join-Path $engineRoot '.jhentai-engine') | Out-Null
}
if (Test-Path $adapterRoot) { Remove-Item -LiteralPath $adapterRoot -Recurse -Force }
Copy-Item -LiteralPath $bundledAdapter -Destination $adapterRoot -Recurse

if (-not (Test-Path $venvPython)) {
    Report 28 '正在创建隔离运行环境'
    & $pythonExe -m venv $venvRoot
}

Report 35 '正在更新安装工具'
& $venvPython -m pip install --disable-pip-version-check --upgrade pip setuptools wheel
if ([System.Convert]::ToBoolean($UseCuda)) {
    Report 38 '检测到 NVIDIA 显卡，正在安装 CUDA 12.8 加速组件'
    & $venvPython -m pip install --disable-pip-version-check torch==2.10.0 torchvision==0.25.0 --index-url https://download.pytorch.org/whl/cu128
    & $venvPython -c "import sys, torch; sys.exit(0 if torch.cuda.is_available() else 1)"
    if ($LASTEXITCODE -eq 0) {
        Set-Content -LiteralPath (Join-Path $RuntimeRoot 'cuda.txt') -Value 'cu128' -Encoding ascii
        Report 40 'CUDA 加速可用'
    } else {
        Remove-Item -LiteralPath (Join-Path $RuntimeRoot 'cuda.txt') -Force -ErrorAction SilentlyContinue
        Report 40 'CUDA 不可用，将自动使用 CPU 兼容模式'
    }
}
Report 42 '正在安装图片识别与修复依赖（下载量较大）'
& $venvPython -m pip install --disable-pip-version-check -r (Join-Path $engineRoot 'requirements.txt')
Report 70 '正在安装 JHenTai 本地服务'
& $venvPython -m pip install --disable-pip-version-check -r (Join-Path $adapterRoot 'requirements.txt')

Report 78 '正在下载并校验检测、OCR 和擦字模型'
$env:PYTHONPATH = $engineRoot
$env:MT_MODEL_DIR = Join-Path $RuntimeRoot 'models'
& $venvPython (Join-Path $adapterRoot 'prepare_models.py')

Set-Content -LiteralPath (Join-Path $RuntimeRoot 'initialized.txt') -Value 'v1' -Encoding ascii
Report 100 '翻译环境初始化完成'
