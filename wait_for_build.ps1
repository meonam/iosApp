$headers = @{ "Authorization" = "token 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"; "Accept" = "application/vnd.github.v3+json" }
$runId = 36283238082
Write-Output "Waiting for build $runId to complete..."
while ($true) {
    $response = Invoke-RestMethod -Uri "https://api.github.com/repos/meonam/iosApp/actions/runs/$runId" -Headers $headers
    if ($response.status -eq "completed") {
        Write-Output "Build completed with conclusion: $($response.conclusion)"
        if ($response.conclusion -eq "success") {
            Write-Output "Downloading artifact..."
            $arts = Invoke-RestMethod -Uri "https://api.github.com/repos/meonam/iosApp/actions/runs/$runId/artifacts" -Headers $headers
            if ($arts.total_count -gt 0) {
                $artUrl = $arts.artifacts[0].archive_download_url
                New-Item -ItemType Directory -Force -Path "E:\CODE\Android\APP\QLTB\release\iOS" | Out-Null
                $outPath = "E:\CODE\Android\APP\QLTB\release\iOS\QLTB_iOS.zip"
                Invoke-WebRequest -Uri $artUrl -Headers $headers -OutFile $outPath
                Write-Output "Downloaded artifact to $outPath"
                Expand-Archive -Path $outPath -DestinationPath "E:\CODE\Android\APP\QLTB\release\iOS" -Force
                Write-Output "Extracted artifact. Done."
            } else {
                Write-Output "No artifacts found."
            }
        } else {
            # fetch logs for failure
            $jobs = Invoke-RestMethod -Uri "https://api.github.com/repos/meonam/iosApp/actions/runs/$runId/jobs" -Headers $headers
            foreach ($job in $jobs.jobs) {
                if ($job.conclusion -eq "failure") {
                    Write-Output "Failed job: $($job.name). URL: $($job.html_url)"
                }
            }
        }
        break
    }
    Start-Sleep -Seconds 10
}
