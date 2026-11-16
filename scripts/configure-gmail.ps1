# Accept an optional preselected test recipient.
param([string]$TestRecipient = '')
$ErrorActionPreference = 'Stop'
# Explain the private sender setup in its own window.
$Host.UI.RawUI.WindowTitle = 'StockWise - Private Gmail sender setup'
Write-Host 'Configure the app Gmail sender for StockWise.'
Write-Host 'Use a Google app password, not your normal Gmail password.'
Write-Host 'Credentials go directly to Firebase Secret Manager. They are not saved in this folder or in chat.'
Write-Host 'Create an app password at https://myaccount.google.com/apppasswords'
Write-Host 'Setup sends one clearly labelled sample confirmation to a verified customer login email.'
Write-Host 'Once configured, previously queued order confirmations can also be delivered automatically.'
# Collect the sender address and verified customer test email.
$senderAddress = Read-Host 'App Gmail address'
$testCustomerEmail = $TestRecipient
if ([string]::IsNullOrWhiteSpace($testCustomerEmail)) {
    $testCustomerEmail = Read-Host 'Verified customer login email to receive the test confirmation'
} else {
    Write-Host "Test confirmation will go to: $testCustomerEmail"
}
# Read the app password without displaying it.
$senderPassword = Read-Host '16-character app password (hidden)' -AsSecureString
$pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($senderPassword)
# Pass private input directly to the Node setup process.
try {
    $secretText = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
    $inputJson = @{email = $senderAddress; password = $secretText; testEmail = $testCustomerEmail} | ConvertTo-Json -Compress
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = (Get-Command node).Source
    $startInfo.Arguments = '"' + (Join-Path $PSScriptRoot 'configure-gmail.cjs') + '"'
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardInput = $true
    $process = [System.Diagnostics.Process]::Start($startInfo)
    $process.StandardInput.Write($inputJson)
    $process.StandardInput.Close()
    $secretText = $null
    $inputJson = $null
    $process.WaitForExit()
    $setupExitCode = $process.ExitCode
    $process.Dispose()
# Clear the password buffers after setup finishes.
} finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
    $senderPassword.Dispose()
    $secretText = $null
    $inputJson = $null
}
# Show whether sender configuration completed successfully.
if ($setupExitCode -eq 0) {
    Write-Host 'Setup complete. Check the customer inbox for the StockWise test confirmation.' -ForegroundColor Green
} else {
    Write-Host 'Setup was not completed. You can run this window again when ready.' -ForegroundColor Yellow
}
Read-Host 'Press Enter to close'
exit $setupExitCode
