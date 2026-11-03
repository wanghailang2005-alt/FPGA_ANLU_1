param(
    [ValidateSet('all','prepare','simulate','build','collect')][string]$Step='all',
    [string]$Python='C:\Users\Wang\AppData\Local\Programs\Python\Python314\python.exe',
    [string]$ModelSim='E:\Modelsim\win64\vsim.exe',
    [string]$TD='E:\Anlogic\TD_6.2.1_Engineer_6.2.168.116\bin\td_commands_prompt.exe'
)
$ErrorActionPreference='Stop'
function Invoke-Checked([string]$Executable,[string[]]$Arguments) {
    & $Executable @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Executable failed: $LASTEXITCODE" }
}
Push-Location -LiteralPath $PSScriptRoot
try {
    if ($Step -in @('all','prepare')) {
        Invoke-Checked $Python @('tools/prepare_spectrum.py')
    }
    if ($Step -in @('all','simulate')) {
        Push-Location -LiteralPath 'spectrum_sim'
        try {
            Invoke-Checked $Python @('check_fft.py','--generate')
            foreach ($suite in @('fft','analysis','captions','spectrum','scene','checksum','cache')) {
                Invoke-Checked $ModelSim @('-c','-do',"$suite.do",'-l',"$suite.log")
                if ($suite -eq 'fft') { Invoke-Checked $Python @('check_fft.py') }
            }
        } finally { Pop-Location }
    }
    if ($Step -in @('all','build')) {
        foreach ($stage in @('syn_1','phy_1')) {
            Push-Location -LiteralPath "src/td_project/HDMI1.4b_Transmitter_v1.0_Runs/$stage"
            try { Invoke-Checked $TD @('../../../../build_td.tcl') }
            finally { Pop-Location }
        }
    }
    if ($Step -in @('all','collect')) {
        Invoke-Checked $TD @('tools/verify_font_rom.tcl')
        Invoke-Checked $Python @('tools/verify_font_rom.py')
        Invoke-Checked $Python @('tools/collect_spectrum.py')
    }
} finally { Pop-Location }
