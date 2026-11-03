param(
 [ValidateSet('all','prepare','simulate','build','collect')][string]$Step='all',
 [string]$Python='C:\Users\Wang\AppData\Local\Programs\Python\Python314\python.exe',
 [string]$ModelSim='E:\Modelsim\win64\vsim.exe',
 [string]$TD='E:\Anlogic\TD_6.2.1_Engineer_6.2.168.116\bin\td_commands_prompt.exe'
)
$ErrorActionPreference='Stop'
function Invoke-Checked([string]$Executable,[string[]]$Arguments) {
 & $Executable @Arguments
 if ($LASTEXITCODE -ne 0) {throw "$Executable failed: $LASTEXITCODE"}
}
Push-Location -LiteralPath $PSScriptRoot
try {
 if($Step -in @('all','prepare')) {Invoke-Checked $Python @('tools/prepare_music.py')}
 if($Step -in @('all','simulate')) {
  Push-Location -LiteralPath 'music_sim'
  try {foreach($suite in @('music','real_music','keys','cdc')) {
   Invoke-Checked $ModelSim @('-c','-do',"$suite.do",'-l',"$suite.log")
  }} finally {Pop-Location}
 }
 if($Step -in @('all','build')) {
  foreach($stage in @('syn_1','phy_1')) {
   Push-Location -LiteralPath "src/td_project/HDMI1.4b_Transmitter_v1.0_Runs/$stage"
   try {Invoke-Checked $TD @('../../../../build_td.tcl')} finally {Pop-Location}
  }
  # Explicit repair is necessary when TD's automatic hold pass skips dense designs.
  Invoke-Checked $TD @('tools/fix_music_hold.tcl')
 }
 if($Step -in @('all','collect')) {
  Invoke-Checked $TD @('music_evidence/font_probe.tcl')
  Invoke-Checked $Python @('music_evidence/verify_font.py')
  Invoke-Checked $Python @('tools/collect_music.py')
  $summary=Get-Content -Raw -LiteralPath 'music_evidence/final/summary.json' | ConvertFrom-Json
  if(-not $summary.timing_pass) {throw 'Implementation timing has not passed; no release bit was published.'}
 }
} finally {Pop-Location}
