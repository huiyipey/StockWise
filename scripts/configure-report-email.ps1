$ErrorActionPreference = 'Stop'
# Run locally. Read-Host masks input; the password is never written to a file.
$mailPassword = Read-Host 'Gmail app password for huiyipey@gmail.com (input hidden)' -AsSecureString
$mailPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($mailPassword)
try {
    $mailPlain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($mailPointer).Replace(' ', '')
    if ($mailPlain.Length -ne 16) { throw 'Expected a 16-character Gmail app password.' }
    $mailJson = @{host='smtp.gmail.com'; port=465; secure=$true; user='huiyipey@gmail.com'; from='StockWise <huiyipey@gmail.com>'; password=$mailPlain} | ConvertTo-Json -Compress
    $mailJson | firebase functions:secrets:set REPORT_SMTP_CONFIG --data-file - --project stockwise-190a9 --account huiyipey@gmail.com
    if ($LASTEXITCODE -ne 0) { throw 'Secret setup failed.' }
    node (Join-Path $PSScriptRoot 'grant-mail-access.cjs')
    if ($LASTEXITCODE -ne 0) { throw 'Credential is stored, but the function access grant needs to be retried after deployment.' }
    Write-Output 'Email credentials stored in Secret Manager. No local password file was created.'
} finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($mailPointer)
    $mailPlain = $null
    $mailJson = $null
    $mailPassword.Dispose()
}
