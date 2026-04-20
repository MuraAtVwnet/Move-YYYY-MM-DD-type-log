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

# 対象フォルダー内の .log を取得
$Files = Get-ChildItem -Path $BasePath -Filter '*.log' -File -ErrorAction Stop

foreach ($File in $Files) {
    # ファイル名から yyyy-MM-dd を抽出
    if ($File.Name -match '(?<DateText>\d{4}-\d{2}-\d{2})') {
        $DateText = $Matches['DateText']

        try {
            $FileDate = [datetime]::ParseExact($DateText, 'yyyy-MM-dd', $null)
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
