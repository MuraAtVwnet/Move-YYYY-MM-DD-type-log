param(
    [Parameter(Mandatory = $false)]
    [ValidatePattern('^\d{4}-\d{2}$')]
    [string]$TargetMonth
)

# 対象フォルダー
$BasePath = 'C:\Log'

# 引数未指定なら前月
if ([string]::IsNullOrWhiteSpace($TargetMonth)) {
    $ProcessMonth = (Get-Date).AddMonths(-1).ToString('yyyy-MM')
}
else {
    $ProcessMonth = $TargetMonth
}

Write-Host "処理対象月: $ProcessMonth"

# 対象月の年月情報
try {
    $ProcessDate = [datetime]::ParseExact(($ProcessMonth + '-01'), 'yyyy-MM-dd', $null)
}
catch {
    throw "TargetMonth の形式が不正です。YYYY-MM 形式で指定してください。"
}

# .log ファイルを対象月のフォルダーへ移動
$Files = Get-ChildItem -Path $BasePath -Filter '*.log' -File -ErrorAction Stop

foreach ($File in $Files) {
    if ($File.Name -match '(?<DateText>\d{4}-\d{2}-\d{2})') {
        $DateText = $Matches['DateText']

        try {
            $FileDate  = [datetime]::ParseExact($DateText, 'yyyy-MM-dd', $null)
            $FileMonth = $FileDate.ToString('yyyy-MM')

            # 指定月だけ処理
            if ($FileMonth -ne $ProcessMonth) {
                continue
            }

            $DestinationFolder = Join-Path -Path $BasePath -ChildPath $FileMonth

            if (-not (Test-Path -LiteralPath $DestinationFolder)) {
                New-Item -Path $DestinationFolder -ItemType Directory -Force -ErrorAction Stop | Out-Null
            }

            $DestinationPath = Join-Path -Path $DestinationFolder -ChildPath $File.Name

            Move-Item -LiteralPath $File.FullName -Destination $DestinationPath -Force -ErrorAction Stop
            Write-Host "移動成功: $($File.Name) -> $FileMonth"
        }
        catch {
            Write-Warning "移動失敗: $($File.FullName)"
            Write-Warning $_.Exception.Message
        }
    }
    else {
        Write-Warning "日付形式を判定できないためスキップ: $($File.Name)"
    }
}

# 1月を処理対象にした場合は、前年分の月フォルダーを前年フォルダー配下へまとめる
if ($ProcessDate.Month -eq 1) {
    $PreviousYear = ($ProcessDate.Year - 1).ToString()
    $YearFolder   = Join-Path -Path $BasePath -ChildPath $PreviousYear

    if (-not (Test-Path -LiteralPath $YearFolder)) {
        try {
            New-Item -Path $YearFolder -ItemType Directory -Force -ErrorAction Stop | Out-Null
            Write-Host "年フォルダー作成: $YearFolder"
        }
        catch {
            Write-Warning "年フォルダー作成失敗: $YearFolder"
            Write-Warning $_.Exception.Message
        }
    }

    # 前年の月フォルダー (YYYY-MM) を列挙
    $PreviousYearMonthFolders = Get-ChildItem -Path $BasePath -Directory -ErrorAction Stop |
        Where-Object {
            $_.Name -match ('^{0}-(0[1-9]|1[0-2])$' -f [regex]::Escape($PreviousYear))
        }

    foreach ($MonthFolder in $PreviousYearMonthFolders) {
        try {
            $DestinationYearChild = Join-Path -Path $YearFolder -ChildPath $MonthFolder.Name

            # 既に前年フォルダー内に同名フォルダーがある場合はスキップ
            if (Test-Path -LiteralPath $DestinationYearChild) {
                Write-Warning "移動先に同名フォルダーが既に存在するためスキップ: $DestinationYearChild"
                continue
            }

            Move-Item -LiteralPath $MonthFolder.FullName -Destination $YearFolder -ErrorAction Stop
            Write-Host "年次整理: $($MonthFolder.Name) -> $PreviousYear\$($MonthFolder.Name)"
        }
        catch {
            Write-Warning "年次整理失敗: $($MonthFolder.FullName)"
            Write-Warning $_.Exception.Message
        }
    }
}

