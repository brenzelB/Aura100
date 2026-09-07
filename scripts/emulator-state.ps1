param([ValidateSet('emulator-5554','emulator-5556')][string]$Serial='emulator-5554')
$auditAdb = Join-Path $env:LOCALAPPDATA 'Android\sdk\platform-tools\adb.exe'
$auditDump = & $auditAdb -s $Serial shell uiautomator dump /sdcard/aura-audit.xml 2>&1
if ($auditDump -notmatch 'dumped to:') { throw "No fresh UI snapshot: $auditDump" }
[xml]$auditXml = (& $auditAdb -s $Serial shell cat /sdcard/aura-audit.xml) -join "`n"
$auditXml.SelectNodes('//*[@content-desc!="" or @text!=""]') | ForEach-Object {
  [pscustomobject]@{Label=($_.'content-desc'+$_.text);Bounds=$_.bounds;Clickable=$_.clickable}
} | ConvertTo-Json -Compress
