# Write your code here
$ResourceGroup = Get-AzDisk -ResourceGroupName "mate-azure-task-2-ukwest"
foreach($diskstate in $ResourceGroup) {
  if($diskstate.DiskState -eq "Unattached") {
    $diskstate | ConvertTo-Json | Out-File -Path ./result.json
  }
}