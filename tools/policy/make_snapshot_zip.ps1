param([string]$Source=(Resolve-Path ".").Path,[string]$OutZip=(Join-Path (Resolve-Path "$env:USERPROFILE\Downloads").Path "tfws_ap_PROD_snapshot.zip"))
if(Test-Path $OutZip){Remove-Item -Force $OutZip}
Compress-Archive -Force -Path (Join-Path $Source "*") -DestinationPath $OutZip; Write-Host "OK: $OutZip"
