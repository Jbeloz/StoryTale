$ErrorActionPreference = 'Stop'

$word = New-Object -ComObject Word.Application
$word.Visible = $false
$word.DisplayAlerts = 0

$out = 'C:\Users\Houro\Desktop\IT Elect 4\storytale\docs\project-management\week3\tmp\docx-render'
New-Item -ItemType Directory -Force -Path $out | Out-Null

$files = @(
    'C:\Users\Houro\Desktop\IT Elect 4\storytale\docs\project-management\week3\StoryTale_Milestones_and_Deliverables.docx',
    'C:\Users\Houro\Desktop\IT Elect 4\storytale\docs\project-management\week3\StoryTale_Risk_Assessment_and_Contingency_Plan.docx'
)

try {
    foreach ($file in $files) {
        $document = $word.Documents.Open($file, $false, $true)
        $pdfName = [System.IO.Path]::GetFileNameWithoutExtension($file) + '.pdf'
        $pdfPath = Join-Path $out $pdfName
        $document.ExportAsFixedFormat($pdfPath, 17)
        $document.Close($false)
        Write-Output $pdfPath
    }
}
finally {
    $word.Quit()
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($word) | Out-Null
}
