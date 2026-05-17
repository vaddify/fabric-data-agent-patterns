Get-ChildItem 'c:\Users\shasvaddi\OneDrive - Microsoft\Documents\Vaddify-Labs\patterns\01-fabric-data-agent-semantic-readiness\assets\model' -Recurse -File |
  Select-Object @{n='Path';e={ $_.FullName.Replace('C:\Users\shasvaddi\OneDrive - Microsoft\Documents\Vaddify-Labs\patterns\01-fabric-data-agent-semantic-readiness\assets\model\','') }},
                @{n='KB';e={ [math]::Round($_.Length/1024,2) }} |
  Format-Table -AutoSize
