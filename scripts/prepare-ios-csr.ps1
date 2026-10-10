$ErrorActionPreference = 'Stop'
$privateDirectory = Join-Path (Split-Path $PSScriptRoot -Parent) 'build/apple-private'
$opensslPath = 'C:/Program Files/Git/usr/bin/openssl.exe'
if (-not (Test-Path -LiteralPath $opensslPath)) { throw 'Git OpenSSL was not found.' }
New-Item -ItemType Directory -Force -Path $privateDirectory | Out-Null
$keyPath = Join-Path $privateDirectory 'distribution-key.encrypted.pem'
$requestPath = Join-Path $privateDirectory 'AuraQuest-Distribution.csr'
$passwordPath = Join-Path $privateDirectory 'distribution-password.dpapi'
foreach ($artifactPath in @($keyPath, $requestPath, $passwordPath)) {
    if (Test-Path -LiteralPath $artifactPath) { throw 'Signing request already exists. Do not overwrite its private key.' }
}
$randomBytes = New-Object byte[] 32
$randomSource = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$randomSource.GetBytes($randomBytes)
$randomSource.Dispose()
$keyPassword = [Convert]::ToBase64String($randomBytes)
$protectedPassword = ConvertFrom-SecureString (ConvertTo-SecureString $keyPassword -AsPlainText -Force)
[System.IO.File]::WriteAllText($passwordPath, $protectedPassword)
try {
    $env:AURAQUEST_KEY_PASSPHRASE = $keyPassword
    & $opensslPath genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -aes-256-cbc -pass env:AURAQUEST_KEY_PASSPHRASE -out $keyPath 2>$null
    if ($LASTEXITCODE -ne 0) { throw 'Private-key generation failed.' }
    & $opensslPath req -new -sha256 -key $keyPath -passin env:AURAQUEST_KEY_PASSPHRASE -subj '/CN=Denis Brandt/OU=W558BUSST2/C=DE' -out $requestPath
    if ($LASTEXITCODE -ne 0) { throw 'Certificate request generation failed.' }
    & $opensslPath req -in $requestPath -noout -verify -subject
    if ($LASTEXITCODE -ne 0) { throw 'Certificate request verification failed.' }
    Write-Output 'CSR prepared. The private key is encrypted; its random password is protected by Windows DPAPI.'
    Write-Output $requestPath
} finally {
    Remove-Item Env:AURAQUEST_KEY_PASSPHRASE -ErrorAction SilentlyContinue
    $keyPassword = $null
    if (-not (Test-Path -LiteralPath $keyPath)) {
        Remove-Item -LiteralPath $passwordPath -ErrorAction SilentlyContinue
    }
}
