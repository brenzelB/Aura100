$ErrorActionPreference = 'Stop'
$privateDirectory = Join-Path (Split-Path $PSScriptRoot -Parent) 'build/apple-private'
$opensslPath = 'C:/Program Files/Git/usr/bin/openssl.exe'
$certificatePath = Join-Path $privateDirectory 'AppleDistribution.cer'
$certificatePemPath = Join-Path $privateDirectory 'AppleDistribution.pem'
$keyPath = Join-Path $privateDirectory 'distribution-key.encrypted.pem'
$passwordPath = Join-Path $privateDirectory 'distribution-password.dpapi'
$outputPath = Join-Path $privateDirectory 'distribution.p12'
foreach ($requiredPath in @($opensslPath, $certificatePath, $keyPath, $passwordPath)) {
    if (-not (Test-Path -LiteralPath $requiredPath)) { throw 'Required signing material is missing.' }
}
if (Test-Path -LiteralPath $outputPath) { throw 'Distribution P12 already exists; do not overwrite it.' }
$protectedPassword = ConvertTo-SecureString ([IO.File]::ReadAllText($passwordPath))
$passwordPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($protectedPassword)
try {
    $env:AURAQUEST_KEY_PASSPHRASE = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($passwordPointer)
    $certificatePublicKey = & $opensslPath x509 -inform DER -in $certificatePath -pubkey -noout
    if ($LASTEXITCODE -ne 0) { throw 'Invalid Apple certificate.' }
    $privatePublicKey = & $opensslPath pkey -in $keyPath -passin env:AURAQUEST_KEY_PASSPHRASE -pubout 2>$null
    if ($LASTEXITCODE -ne 0 -or ($certificatePublicKey -join "`n") -ne ($privatePublicKey -join "`n")) {
        throw 'Certificate does not match the prepared private key.'
    }
    $subject = & $opensslPath x509 -inform DER -in $certificatePath -noout -subject
    if ($LASTEXITCODE -ne 0 -or $subject -notmatch 'OU\s*=\s*W558BUSST2' -or $subject -notmatch 'Apple Distribution') {
        throw 'Certificate is not the approved team distribution identity.'
    }
    & $opensslPath x509 -inform DER -in $certificatePath -noout -checkend 86400
    if ($LASTEXITCODE -ne 0) { throw 'Certificate expires too soon.' }
    & $opensslPath x509 -inform DER -in $certificatePath -out $certificatePemPath
    if ($LASTEXITCODE -ne 0) { throw 'Certificate conversion failed.' }
    & $opensslPath pkcs12 -export -inkey $keyPath -in $certificatePemPath -passin env:AURAQUEST_KEY_PASSPHRASE -passout env:AURAQUEST_KEY_PASSPHRASE -name 'Aura Quest Apple Distribution' -out $outputPath 2>$null
    if ($LASTEXITCODE -ne 0) { throw 'Distribution P12 export failed.' }
    & $opensslPath pkcs12 -in $outputPath -passin env:AURAQUEST_KEY_PASSPHRASE -info -noout 2>$null
    if ($LASTEXITCODE -ne 0) { throw 'Distribution P12 verification failed.' }
    Write-Output 'Apple team, key match, expiry and encrypted P12 verified. No credential transmitted or logged.'
} finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passwordPointer)
    Remove-Item Env:AURAQUEST_KEY_PASSPHRASE -ErrorAction SilentlyContinue
}
