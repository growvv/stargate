Add-Type -AssemblyName System.Speech
$root = 'E:\CodeE\vibe51\Stargate\submission\video'
$data = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'script.json') | ConvertFrom-Json
$s = New-Object System.Speech.Synthesis.SpeechSynthesizer
$s.SelectVoice('Microsoft Huihui Desktop')
$s.Rate = 2
$s.Volume = 100
$fmt = New-Object System.Speech.AudioFormat.SpeechAudioFormatInfo(24000, [System.Speech.AudioFormat.AudioBitsPerSample]::Sixteen, [System.Speech.AudioFormat.AudioChannel]::Mono)
foreach ($seg in $data) {
    $id = [int]$seg.id
    for ($j = 0; $j -lt $seg.sentences.Count; $j++) {
        $path = Join-Path $root ('tts\s{0:D2}_{1:D2}.wav' -f $id, ($j + 1))
        $s.SetOutputToWaveFile($path, $fmt)
        $s.Speak($seg.sentences[$j])
        $s.SetOutputToNull()
    }
}
$s.Dispose()
Write-Output ('tts done: ' + $data.Count + ' segments')
