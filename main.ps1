<#
.SYNOPSIS
    PowerShell-скрипт для оптимизации настроек AMD GPU.

.DESCRIPTION
    Этот скрипт предоставляет способ применения различных настроек к параметрам AMD GPU в реестре Windows.
    Он включает функции создания точки восстановления системы, резервного копирования и восстановления настроек,
    а также применения различных профилей оптимизации на основе выбора пользователя.

.NOTES
    Author: sanya
    Date: 2025-12-12

#>

# =================================================================================
# ТАБЛИЦА СТРОК ИНТЕРФЕЙСА (ДЛЯ ЛОКАЛИЗАЦИИ)
# =================================================================================
$uiStrings = @{
    WindowTitle           = "AMD GPU Optimizer"
    Header                = "     AMD GPU Optimizer [v1.0]"
    
    AdminError            = "Этот скрипт должен быть запущен с правами администратора."
    
    CreateRestorePoint    = "[i] Попытка создания точки восстановления системы..."
    RestorePointSubText   = "    (Если это не удастся, скрипт автоматически продолжит работу)"
    RestorePointOK        = "[OK] Точка восстановления успешно создана."
    RestorePointWarn      = "[!] ВНИМАНИЕ: Создание точки восстановления пропущено (служба отключена или произошла ошибка)."
    RestorePointProceed   = "    Продолжение оптимизации..."

    GpuSearch             = "[i] Поиск видеокарты AMD в реестре..."
    GpuFound              = "[OK] Видеокарта найдена по адресу: {0}"
    GpuNotFound           = "Видеокарта AMD не найдена. Выход."

    BackupHeader          = " СИСТЕМА РЕЗЕРВНОГО КОПИРОВАНИЯ И ВОССТАНОВЛЕНИЯ"
    BackupFound           = "[!] НАЙДЕНА СУЩЕСТВУЮЩАЯ РЕЗЕРВНАЯ КОПИЯ: backup_amd_settings.reg"
    BackupQuery           = "Что вы хотите сделать?"
    BackupChoiceRestore   = "1. ВОССТАНОВИТЬ исходные настройки (Отменить изменения)"
    BackupChoiceOverwrite = "2. ПРИМЕНИТЬ настройки снова (Обновить/Перезаписать резервную копию)"
    BackupChoicePrompt    = "Выберите (1 или 2)"
    InvalidChoice         = "Неверный выбор. Пожалуйста, введите 1 или 2."
    
    Restoring             = "[i] Восстановление реестра из {0}..."
    RestoreOK             = "[OK] Восстановление успешно завершено!"
    RestoreRestart        = "Пожалуйста, перезагрузите компьютер."
    RestoreFail           = "[ОШИБКА] Не удалось выполнить восстановление. Проверьте права администратора."

    BackupUpdating        = "[i] Обновление файла резервной копии..."
    BackupCreating        = "[i] Создание нового файла резервной копии..."
    BackupOK              = "[OK] Резервная копия сохранена в: backup_amd_settings.reg"
    BackupFail            = "[!] Внимание: Не удалось создать файл резервной копии."

    MenuOverlayHeader     = " ВОПРОС 1: НАСТРОЙКИ ОВЕРЛЕЯ"
    MenuOverlayChoice1    = "1. ОТКЛЮЧИТЬ оверлей (Макс. FPS, без браузера/метрик)"
    MenuOverlayChoice2    = "2. ВКЛЮЧИТЬ оверлей (По умолчанию, Alt+R работает)"

    MenuGpuHeader         = " ВОПРОС 2: СЕРИЯ GPU И ИСПРАВЛЕНИЯ"
    MenuGpuChoice1        = "1. Серии 5000 / 6000 / 7000"
    MenuGpuChoice1Desc    = "   - АГРЕССИВНЫЕ настройки (LTR=1, DeLag=1)."
    MenuGpuChoice2        = "2. Серии 9000 (RX 9060 XT / 9070 XT)"
    MenuGpuChoice2Desc    = "   - СТАБИЛЬНЫЕ настройки (Исправляет сбой Discord и задержки в вебе)."

    ApplyingTweaks        = "[!] Применение параметров AMD_DWORD_EXTENDED..."
    ApplyingProfile9000   = "[*] Применение профиля для серий 9000 (ИСПРАВЛЕНО)..."
    ApplyingProfileLegacy = "[*] Применение профиля для серий 5000-7000..."
    DisablingOverlay      = "[*] Отключение оверлея..."
    EnablingOverlay       = "[*] Включение оверлея..."
    DisablingTelemetry    = "[*] Отключение телеметрии AUEP..."

    FinalMessageHeader    = " ГОТОВО! Все действительные параметры восстановлены и применены."
    FinalMessageRestart   = " Пожалуйста, ПЕРЕЗАГРУЗИТЕ ваш компьютер."
}


function Show-Intro {
    Clear-Host
    $host.UI.RawUI.WindowTitle = $uiStrings.WindowTitle
    Write-Host "================================================================" -ForegroundColor Green
    Write-Host $uiStrings.Header -ForegroundColor Green
    Write-Host "================================================================" -ForegroundColor Green
    Write-Host ""
}

function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal $(New-Object Security.Principal.WindowsIdentity).GetCurrent()
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function New-RestorePoint {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()

    Write-Host $uiStrings.CreateRestorePoint
    Write-Host $uiStrings.RestorePointSubText
    
    if ($PSCmdlet.ShouldProcess("System", "Create Restore Point")) {
        try {
            Checkpoint-Computer -Description "AMD_DWORD_EXTENDED_Backup" -RestorePointType "MODIFY_SETTINGS" -ErrorAction SilentlyContinue
            Write-Host $uiStrings.RestorePointOK -ForegroundColor Green
        }
        catch {
            Write-Warning $uiStrings.RestorePointWarn
            Write-Warning $uiStrings.RestorePointProceed
        }
    }
    Write-Host ""
}

function Get-AmdGpu {
    Write-Host $uiStrings.GpuSearch
    $gpuClassKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
    $subKeys = Get-ChildItem -Path $gpuClassKey | ForEach-Object { $_.PSChildName }

    foreach ($key in $subKeys) {
        $gpuPath = "$gpuClassKey\$key"
        try {
            $driverDesc = (Get-ItemProperty -Path $gpuPath -Name "DriverDesc" -ErrorAction Stop).DriverDesc
            if ($driverDesc -match "AMD" -or $driverDesc -match "Advanced Micro Devices" -or $driverdesc -match "ATI" -or $driverDesc -match "Radeon") {
                Write-Host ($uiStrings.GpuFound -f $key) -ForegroundColor Green
                return $gpuPath
            }
        }
        catch {
            # Key probably doesn't have a DriverDesc value, continue to the next one.
        }
    }

    return $null
}

function Manage-Backup {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory=$true)]
        [string]$GpuKey
    )

    $backupFile = "$PSScriptRoot\backup_amd_settings.reg"

    Write-Host "================================================================"
    Write-Host $uiStrings.BackupHeader
    Write-Host "================================================================"

    if (Test-Path $backupFile) {
        Write-Host ""
        Write-Host $uiStrings.BackupFound -ForegroundColor Yellow
        Write-Host ""
        
        do {
            Write-Host $uiStrings.BackupQuery
            Write-Host $uiStrings.BackupChoiceRestore
            Write-Host $uiStrings.BackupChoiceOverwrite
            Write-Host ""
            $backupChoice = Read-Host $uiStrings.BackupChoicePrompt
            if ($backupChoice -notin "1", "2") {
                Write-Warning $uiStrings.InvalidChoice
            }
        } until ($backupChoice -in "1", "2")


        if ($backupChoice -eq "1") {
            if ($PSCmdlet.ShouldProcess($backupFile, "Registry Restore")) {
                Write-Host ""
                Write-Host ($uiStrings.Restoring -f $backupFile)
                reg import "$backupFile"
                if ($LASTEXITCODE -eq 0) {
                    Write-Host $uiStrings.RestoreOK -ForegroundColor Green
                    Write-Host $uiStrings.RestoreRestart
                    pause
                    exit
                } else {
                    Write-Error $uiStrings.RestoreFail
                    pause
                    exit
                }
            }
            return
        }
    }

    if ($PSCmdlet.ShouldProcess($GpuKey, "Registry Backup")) {
        Write-Host ""
        if (Test-Path $backupFile) {
            Write-Host $uiStrings.BackupUpdating
        } else {
            Write-Host $uiStrings.BackupCreating
        }

        reg export "$GpuKey" "$backupFile" /y
        if (Test-Path $backupFile) {
            Write-Host $uiStrings.BackupOK -ForegroundColor Green
        } else {
            Write-Warning $uiStrings.BackupFail
        }
    }
}

function Show-Menu {
    Write-Host ""
    Write-Host "================================================================"
    Write-Host $uiStrings.MenuOverlayHeader
    Write-Host "================================================================"
    Write-Host ""
    
    do {
        Write-Host $uiStrings.MenuOverlayChoice1
        Write-Host $uiStrings.MenuOverlayChoice2
        Write-Host ""
        $overlayChoice = Read-Host $uiStrings.BackupChoicePrompt
        if ($overlayChoice -notin "1", "2") {
            Write-Warning $uiStrings.InvalidChoice
        }
    } until ($overlayChoice -in "1", "2")


    Write-Host ""
    Write-Host "================================================================"
    Write-Host $uiStrings.MenuGpuHeader
    Write-Host "================================================================"
    Write-Host ""

    do {
        Write-Host $uiStrings.MenuGpuChoice1
        Write-Host $uiStrings.MenuGpuChoice1Desc
        Write-Host ""
        Write-Host $uiStrings.MenuGpuChoice2
        Write-Host $uiStrings.MenuGpuChoice2Desc
        Write-Host ""
        $gpuSeries = Read-Host $uiStrings.BackupChoicePrompt
        if ($gpuSeries -notin "1", "2") {
            Write-Warning $uiStrings.InvalidChoice
        }
    } until ($gpuSeries -in "1", "2")

    return [PSCustomObject]@{
        Overlay = $overlayChoice
        GpuSeries = $gpuSeries
    }
}

function Apply-Tweaks {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory=$true)]
        [string]$GpuKey,
        
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$UserChoices
    )

    Write-Host ""
    Write-Host $uiStrings.ApplyingTweaks -ForegroundColor Yellow

    $umdKey = "$GpuKey\UMD"
    $dxvaKey = "$GpuKey\UMD\DXVA"
    $dxcKey = "$GpuKey\UMD\DXC"

    # Helper function to reduce repetition
    function Set-RegValues($path, $settings) {
        foreach ($setting in $settings) {
            $target = "Registry::${path}"
            $action = "Set '$($setting.Name)' to '$($setting.Value)'"
            if ($PSCmdlet.ShouldProcess($target, $action)) {
                Set-ItemProperty -Path $path -Name $setting.Name -Value $setting.Value -Type $setting.Type -Force
            }
        }
    }

    # BLOCK 1 & 2: CORE & XG TWEAKS
    $coreDwordSettings = @(
        [pscustomobject]@{ Name = "EnableUlps"; Value = 0 }, [pscustomobject]@{ Name = "DisableDMACopy"; Value = 1 },
        [pscustomobject]@{ Name = "DisableBlockWrite"; Value = 0 }, [pscustomobject]@{ Name = "StutterMode"; Value = 0 },
        [pscustomobject]@{ Name = "PP_SclkDeepSleepDisable"; Value = 1 }, [pscustomobject]@{ Name = "PP_ThermalAutoThrottlingEnable"; Value = 0 },
        [pscustomobject]@{ Name = "DisableSAMUPowerGating"; Value = 1 }, [pscustomobject]@{ Name = "DisableUVDPowerGatingDynamic"; Value = 1 },
        [pscustomobject]@{ Name = "DisableVCEPowerGating"; Value = 0 }, [pscustomobject]@{ Name = "DisableDrmdmaPowerGating"; Value = 1 },
        [pscustomobject]@{ Name = "EnableAspmL1"; Value = 1 }, [pscustomobject]@{ Name = "EnableAspmL0s"; Value = 0 },
        [pscustomobject]@{ Name = "DisablePowerGating"; Value = 1 }, [pscustomobject]@{ Name = "PP_GPUPowerDownEnabled"; Value = 1 },
        [pscustomobject]@{ Name = "PP_DisablePowerContainment"; Value = 1 }, [pscustomobject]@{ Name = "PP_DisableVoltageIsland"; Value = 1 },
        [pscustomobject]@{ Name = "KMD_RadeonBoostEnabled"; Value = 0 }, [pscustomobject]@{ Name = "KMD_ChillEnabled"; Value = 0 },
        [pscustomobject]@{ Name = "KMD_FRTEnabled"; Value = 0 }, [pscustomobject]@{ Name = "AllowSnapshot"; Value = 0 },
        [pscustomobject]@{ Name = "AllowSubscription"; Value = 0 }, [pscustomobject]@{ Name = "NotifySubscription"; Value = 0 },
        [pscustomobject]@{ Name = "KMD_EnableComputePreemption"; Value = 0 }, [pscustomobject]@{ Name = "DirAnisoQuality"; Value = 1 },
        [pscustomobject]@{ Name = "MultipleSizeAGP"; Value = 1 }, [pscustomobject]@{ Name = "AntiAlias"; Value = 0 },
        [pscustomobject]@{ Name = "TemporalAAMultiplier"; Value = 0 }, [pscustomobject]@{ Name = "HyperMemory"; Value = 1 },
        [pscustomobject]@{ Name = "OGLCustomSettings"; Value = 1 }, [pscustomobject]@{ Name = "UseNewOGLRegPath"; Value = 1 },
        [pscustomobject]@{ Name = "OGLAlphaDitherMethod"; Value = 1 }, [pscustomobject]@{ Name = "OGLMaxAnisotropy"; Value = 0 },
        [pscustomobject]@{ Name = "OGLWaitVerticalSync"; Value = 0 }, [pscustomobject]@{ Name = "OGLEnableHWPageFlip"; Value = 1 },
        [pscustomobject]@{ Name = "OGLEnableTextureCompression"; Value = 1 }, [pscustomobject]@{ Name = "OGLFullSceneAAScale"; Value = 0 },
        [pscustomobject]@{ Name = "OGLTextureOpt"; Value = 1 }, [pscustomobject]@{ Name = "OGLTruformMode"; Value = 0 },
        [pscustomobject]@{ Name = "HardwarePageFlip"; Value = 1 }, [pscustomobject]@{ Name = "OGLAnisoType"; Value = 0 },
        [pscustomobject]@{ Name = "OGLAnisoPref"; Value = 1 }, [pscustomobject]@{ Name = "OGLAnisoQuality"; Value = 1 },
        [pscustomobject]@{ Name = "OGLMode"; Value = 3 }, [pscustomobject]@{ Name = "OGLSmoothPref"; Value = 1 },
        [pscustomobject]@{ Name = "OGLEnableTripleBuffering"; Value = 1 }, [pscustomobject]@{ Name = "OGLDisableProgPCILatency"; Value = 1 }
    )
    $coreDwordSettings.ForEach({ Set-RegValues -path $GpuKey -settings @{ Name = $_.Name; Value = $_.Value; Type = 'DWORD' } })

    $coreStringSettings = @(
        "FastAALines", "ExportMipMapCubeMaps", "ExportSignedVolTex", "LineAAEnabled", "ExportYUVTex", "ColorFill", "DitherAlpha",
        "ExportWBuffer", "FastWClearEnabled", "FastZClearEnabled", "FastColorClear", "FastColorClearPrimary", "PartialZMaskClears",
        "ExportBumpMappedTex", "ZMaskEnable", "WMaskEnable", "AGPTexture", "TclEnableBackFaceCulling", "LocalTextureTiling",
        "LocalTextureMicroTiling", "AGPTextureMicroTiling", "AGPTextureTiling", "BackBufTiling", "PureDevice", "ForceStencilCompression",
        "ForceCompressedStencil", "VolTxEnable", "RasterGuardbandEnable", "ColorCompression", "HierarchicalZEnable", "TextureTiling",
        "LVB", "PointSprites", "ClipOptimizations", "UseMemBankChoice", "SysMemBlts", "GL_ATI_texture_compression_3dc", "GL_S3_s3tc"
    )
    $coreStringSettings.ForEach({ Set-RegValues -path $GpuKey -settings @{ Name = $_; Value = '1'; Type = 'STRING' } })
    
    Set-RegValues -path $GpuKey -settings @(
        @{ Name = "ZCompressionMode"; Value = "3"; Type = "STRING" }, @{ Name = "ZFormats"; Value = "7"; Type = "STRING" },
        @{ Name = "PixelCenter"; Value = "0"; Type = "STRING" }, @{ Name = "AnisoDegree"; Value = "0"; Type = "STRING" },
        @{ Name = "AnisoType"; Value = "0"; Type = "STRING" }, @{ Name = "AntiAliasSamples"; Value = "0"; Type = "STRING" },
        @{ Name = "ValidateVertexIndex"; Value = "0"; Type = "STRING" }, @{ Name = "EnableUntransformedInLocalMem"; Value = "0"; Type = "STRING" }
    )

    # BLOCK 3: DALRULE RESOLUTIONS
    $dalruleSettings = "DALRULE_RESTRICT640x480MODE", "DALRULE_RESTRICT800x600MODE", "DALRULE_RESTRICT960x720MODE", "DALRULE_RESTRICT1024x768MODE", "DALRULE_RESTRICT1152x864MODE", "DALRULE_RESTRICT1200x900MODE", "DALRULE_RESTRICT1280x786MODE", "DALRULE_RESTRICT1280x960MODE", "DALRULE_RESTRICT1400x900MODE", "DALRULE_RESTRICT1280x1024MODE", "DALRULE_RESTRICT1360x1020MODE", "DALRULE_RESTRICT1400x1050MODE", "DALRULE_RESTRICT1520x1140MODE", "DALRULE_RESTRICT1600x1200MODE", "DALRULE_RESTRICT1792x1344MODE", "DALRULE_RESTRICT1800x1440MODE", "DALRULE_RESTRICT1856x1392MODE", "DALRULE_RESTRICT1920x1200MODE", "DALRULE_RESTRICT2048x1536MODE", "DALRULE_RESTRICT2560x1440MODE", "DALRULE_RESTRICT2800X1050MODE", "DALRULE_RESTRICT3840X1080MODE", "DALRULE_RESTRICT4096X1080MODE", "DALRULE_DISPLAYSRESTRICTMODES"
    $dalruleSettings.ForEach({ Set-RegValues -path $GpuKey -settings @{ Name = $_; Value = 0; Type = 'DWORD' } })
    Set-RegValues -path $GpuKey -settings @{ Name = "DALRULE_AUTOGENERATELARGEDESKTOPMODES"; Value = 1; Type = 'DWORD' }

    # BLOCK 4: UMD SECTION
    if (-not (Test-Path $umdKey)) { if($PSCmdlet.ShouldProcess($umdKey, "Create Key")) { New-Item -Path $umdKey -Force } }
    Set-RegValues -path $umdKey -settings @{ Name = "Main3D_DEF"; Value = "1"; Type = "STRING" }
    $umdBinarySettings = @(
        @{ Name = "Main3D"; Value = ([byte[]](0x31,0x00,0x00,0x00)) }, @{ Name = "Tessellation"; Value = ([byte[]](0x31,0x00,0x00,0x00)) },
        @{ Name = "TextureOpt"; Value = ([byte[]](0x30,0x00,0x00,0x00)) }, @{ Name = "TextureLod"; Value = ([byte[]](0x30,0x00,0x00,0x00)) },
        @{ Name = "CatalystAI"; Value = ([byte[]](0x31,0x00,0x00,0x00)) }, @{ Name = "GI"; Value = ([byte[]](0x31,0x00,0x00,0x00)) },
        @{ Name = "AAF"; Value = ([byte[]](0x30,0x00,0x00,0x00)) }, @{ Name = "ForceZBufferDepth"; Value = ([byte[]](0x30,0x00,0x00,0x00)) },
        @{ Name = "ExportCompressedTex"; Value = ([byte[]](0x31,0x00,0x00,0x00)) }, @{ Name = "PixelCenter"; Value = ([byte[]](0x30,0x00,0x00,0x00)) },
        @{ Name = "SwapEffect"; Value = ([byte[]](0x30,0x00,0x00,0x00)) }, @{ Name = "AnisoType"; Value = ([byte[]](0x30,0x00,0x00,0x00)) },
        @{ Name = "FlipQueueSize"; Value = ([byte[]](0x31,0x00)) }, @{ Name = "Tessellation_OPTION"; Value = ([byte[]](0x32,0x00)) },
        @{ Name = "TFQ"; Value = ([byte[]](0x32,0x00)) }, @{ Name = "ShaderCache"; Value = ([byte[]](0x32,0x00)) },
        @{ Name = "VSyncControl"; Value = ([byte[]](0x31,0x00)) }, @{ Name = "AntiAlias"; Value = ([byte[]](0x31,0x00)) },
        @{ Name = "AntiAliasSamples"; Value = ([byte[]](0x30,0x00)) }, @{ Name = "AnisoDegree"; Value = ([byte[]](0x30,0x00)) },
        @{ Name = "SurfaceFormatReplacements"; Value = ([byte[]](0x31,0x00)) }, @{ Name = "ASTT"; Value = ([byte[]](0x30,0x00)) },
        @{ Name = "ASD"; Value = ([byte[]](0x30,0x00)) }, @{ Name = "ASE"; Value = ([byte[]](0x30,0x00)) },
        @{ Name = "HighQualityAF"; Value = ([byte[]](0x31,0x00)) }, @{ Name = "PowerState"; Value = ([byte[]](0x30,0x00)) },
        @{ Name = "TurboSync"; Value = ([byte[]](0x30,0x00)) }, @{ Name = "EQAA"; Value = ([byte[]](0x30,0x00)) },
        @{ Name = "MLF"; Value = ([byte[]](0x30,0x00)) }, @{ Name = "AntiStuttering"; Value = ([byte[]](0x31,0x00)) },
        @{ Name = "EnableTripleBuffering"; Value = ([byte[]](0x30,0x00)) }
    )
    $umdBinarySettings.ForEach({ Set-RegValues -path $umdKey -settings @{ Name = $_.Name; Value = $_.Value; Type = 'BINARY' } })

    # BLOCK 5: DXVA
    if (-not (Test-Path $dxvaKey)) { if($PSCmdlet.ShouldProcess($dxvaKey, "Create Key")) { New-Item -Path $dxvaKey -Force } }
    $dxvaBinarySettings = @(
        @{ Name = "MosquitoNoiseRemoval_ENABLE"; Value = ([byte[]](0x30,0x00,0x00,0x00)) }, @{ Name = "MosquitoNoiseRemoval"; Value = ([byte[]](0x35,0x00,0x30,0x00,0x00,0x00)) },
        @{ Name = "Deblocking_ENABLE"; Value = ([byte[]](0x30,0x00,0x00,0x00)) }, @{ Name = "Deblocking"; Value = ([byte[]](0x35,0x00,0x30,0x00,0x00,0x00)) },
        @{ Name = "3to2Pulldown"; Value = ([byte[]](0x31,0x00,0x00,0x00)) }, @{ Name = "BlueStretch_ENABLE"; Value = ([byte[]](0x31,0x00,0x00,0x00)) },
        @{ Name = "BlueStretch"; Value = ([byte[]](0x31,0x00,0x00,0x00)) }, @{ Name = "LRTCCoef"; Value = ([byte[]](0x31,0x00,0x30,0x00,0x30,0x00,0x00,0x00)) },
        @{ Name = "Fleshtone_ENABLE"; Value = ([byte[]](0x30,0x00,0x00,0x00)) }, @{ Name = "Fleshtone"; Value = ([byte[]](0x35,0x00,0x30,0x00,0x00,0x00)) },
        @{ Name = "DynamicRange"; Value = ([byte[]](0x30,0x00,0x00,0x00)) }, @{ Name = "StaticGamma_ENABLE"; Value = ([byte[]](0x30,0x00,0x00,0x00)) },
        @{ Name = "DynamicContrast_ENABLE"; Value = ([byte[]](0x30,0x00,0x00,0x00)) }, @{ Name = "WhiteBalanceCorrection"; Value = ([byte[]](0x30,0x00,0x00,0x00)) }
    )
    $dxvaBinarySettings.ForEach({ Set-RegValues -path $dxvaKey -settings @{ Name = $_.Name; Value = $_.Value; Type = 'BINARY' } })

    # BLOCK 6: DXC & OGL PRIVATE
    if (-not (Test-Path $dxcKey)) { if($PSCmdlet.ShouldProcess($dxcKey, "Create Key")) { New-Item -Path $dxcKey -Force } }
    Set-RegValues -path $dxcKey -settings @( @{ Name = "AllowBoost"; Value = "1"; Type = "STRING" }, @{ Name = "AllowDelag"; Value = "1"; Type = "STRING" } )
    
    $oglKey1 = "HKLM:\SYSTEM\CurrentControlSet\Services\ati2mtag\Device3\OpenGL\private"
    if (-not (Test-Path $oglKey1)) { if($PSCmdlet.ShouldProcess($oglKey1, "Create Key")) { New-Item -Path $oglKey1 -Force } }
    $oglDwordSettings1 = "Enable3DNow", "EnableAGPTextures", "EnableAntistropicFiltering", "EnableFastZMaskClear", "EnableMacroTile", "EnableVidMemTextures", "Enable3MicroTile", "Enable3MultiTexture", "Enable3SSE", "EnableTCL", "EnableZCompression", "UseBlt"
    $oglDwordSettings1.ForEach({ Set-RegValues -path $oglKey1 -settings @{ Name = $_; Value = 1; Type = 'DWORD' } })

    $oglKey2 = "HKLM:\SYSTEM\CurrentControlSet\Services\amdwddmg\Device3\OpenGL\private"
    if (Test-Path "HKLM:\SYSTEM\CurrentControlSet\Services\amdwddmg") {
        if (-not (Test-Path $oglKey2)) { if($PSCmdlet.ShouldProcess($oglKey2, "Create Key")) { New-Item -Path $oglKey2 -Force } }
        $oglDwordSettings2 = "Enable3DNow", "EnableAGPTextures", "EnableAntistropicFiltering", "EnableFastZMaskClear"
        $oglDwordSettings2.ForEach({ Set-RegValues -path $oglKey2 -settings @{ Name = $_; Value = 1; Type = 'DWORD' } })
    }

    # LOGIC: GPU SERIES
    if ($UserChoices.GpuSeries -eq "2") {
        Write-Host $uiStrings.ApplyingProfile9000
        Set-RegValues -path $GpuKey -settings @{ Name = "KMD_DeLagEnabled"; Value = 0; Type = 'DWORD' }
        if ($PSCmdlet.ShouldProcess($GpuKey, "Remove LTR* Properties")) {
            Remove-ItemProperty -Path $GpuKey -Name "LTRSnoopL1Latency" -Force -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $GpuKey -Name "LTRSnoopL0Latency" -Force -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $GpuKey -Name "LTRNoSnoopL1Latency" -Force -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $GpuKey -Name "LTRMaxNoSnoopLatency" -Force -ErrorAction SilentlyContinue
        }
    } else {
        Write-Host $uiStrings.ApplyingProfileLegacy
        $ltrSettings = "KMD_DeLagEnabled", "LTRSnoopL1Latency", "LTRSnoopL0Latency", "LTRNoSnoopL1Latency", "LTRMaxNoSnoopLatency"
        $ltrSettings.ForEach({ Set-RegValues -path $GpuKey -settings @{ Name = $_; Value = 1; Type = 'DWORD' } })
    }

    # LOGIC: OVERLAY
    if ($UserChoices.Overlay -eq "1") {
        Write-Host $uiStrings.DisablingOverlay
        Set-RegValues -path $GpuKey -settings @( @{ Name = "AllowRSOverlay"; Value = "false"; Type = "STRING" }, @{ Name = "AllowSkins"; Value = "false"; Type = "STRING" } )
        $cnKey = "HKCU:\Software\AMD\CN"
        if (-not (Test-Path $cnKey)) { if($PSCmdlet.ShouldProcess($cnKey, "Create Key")) { New-Item -Path $cnKey -Force } }
        Set-RegValues -path $cnKey -settings @(
            @{ Name = "RSXBrowserUnavailable"; Value = "true"; Type = "STRING" }, @{ Name = "CN_Hide_Toast_Notification"; Value = "true"; Type = "STRING" },
            @{ Name = "AutoUpdateTriggered"; Value = 0; Type = "DWORD" }, @{ Name = "BuildType"; Value = 0; Type = "DWORD" },
            @{ Name = "SystemTray"; Value = "false"; Type = "STRING" }, @{ Name = "AllowWebContent"; Value = "false"; Type = "STRING" }
        )
        $dvrKey = "HKCU:\Software\AMD\DVR"
        if (-not (Test-Path $dvrKey)) { if($PSCmdlet.ShouldProcess($dvrKey, "Create Key")) { New-Item -Path $dvrKey -Force } }
        Set-RegValues -path $dvrKey -settings @{ Name = "DvrEnabled"; Value = 0; Type = 'DWORD' }
    } else {
        Write-Host $uiStrings.EnablingOverlay
        Set-RegValues -path $GpuKey -settings @( @{ Name = "AllowRSOverlay"; Value = "true"; Type = "STRING" }, @{ Name = "AllowSkins"; Value = "true"; Type = "STRING" } )
        $cnKey = "HKCU:\Software\AMD\CN"
        if (-not (Test-Path $cnKey)) { if($PSCmdlet.ShouldProcess($cnKey, "Create Key")) { New-Item -Path $cnKey -Force } }
        Set-RegValues -path $cnKey -settings @{ Name = "RSXBrowserUnavailable"; Value = "false"; Type = "STRING" }
        $dvrKey = "HKCU:\Software\AMD\DVR"
        if (-not (Test-Path $dvrKey)) { if($PSCmdlet.ShouldProcess($dvrKey, "Create Key")) { New-Item -Path $dvrKey -Force } }
        Set-RegValues -path $dvrKey -settings @{ Name = "DvrEnabled"; Value = 1; Type = 'DWORD' }
    }

    # FINALIZE (AUEP)
    Write-Host $uiStrings.DisablingTelemetry
    $installKey = "HKLM:\Software\AMD\Install"
    if (-not (Test-Path $installKey)) { if($PSCmdlet.ShouldProcess($installKey, "Create Key")) { New-Item -Path $installKey -Force } }
    Set-RegValues -path $installKey -settings @{ Name = "AUEP"; Value = 1; Type = "DWORD" }
    
    $auepKey = "HKLM:\Software\AUEP"
    if (-not (Test-Path $auepKey)) { if($PSCmdlet.ShouldProcess($auepKey, "Create Key")) { New-Item -Path $auepKey -Force } }
    Set-RegValues -path $auepKey -settings @{ Name = "RSX_AUEPStatus"; Value = 2; Type = "DWORD" }

    $adlKey = "HKCU:\Software\ATI\ACE\Settings\ADL\AppProfiles"
    if (-not (Test-Path $adlKey)) { if($PSCmdlet.ShouldProcess($adlKey, "Create Key")) { New-Item -Path $adlKey -Force } }
    Set-RegValues -path $adlKey -settings @{ Name = "AplReloadCounter"; Value = 0; Type = "DWORD" }
}

function Main {
    # Show the intro header
    Show-Intro

    # Check for administrator privileges
    if (-not (Test-Admin)) {
        Write-Error $uiStrings.AdminError
        pause
        exit
    }

    # Create a system restore point
    New-RestorePoint
    
    # Find the AMD GPU in the registry
    $gpuKey = Get-AmdGpu
    if (-not $gpuKey) {
        Write-Error $uiStrings.GpuNotFound
        pause
        exit
    }

    # Manage backup and restore
    Manage-Backup -GpuKey $gpuKey

    # Show the user menu and get choices
    $userChoices = Show-Menu

    # Apply the selected tweaks
    Apply-Tweaks -GpuKey $gpuKey -UserChoices $userChoices

    # Final message
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Green
    Write-Host $uiStrings.FinalMessageHeader -ForegroundColor Green
    Write-Host $uiStrings.FinalMessageRestart -ForegroundColor Green
    Write-Host "================================================================" -ForegroundColor Green
    pause
    exit
}

Main

