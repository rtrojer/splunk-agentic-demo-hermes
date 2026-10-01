[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param()

$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$composeFile = Join-Path $PSScriptRoot 'docker-compose.yml'
$composeProject = Split-Path -Leaf $PSScriptRoot
$gitCommand = Get-Command git -CommandType Application -ErrorAction Stop |
    Select-Object -First 1
$dockerCommand = Get-Command docker -CommandType Application -ErrorAction Stop |
    Select-Object -First 1

if (-not (Test-Path -LiteralPath $composeFile -PathType Leaf)) {
    throw "Docker Compose file not found: $composeFile"
}

Push-Location $projectRoot
try {
    $branch = (& $gitCommand.Source branch --show-current).Trim()
    if ($LASTEXITCODE -ne 0 -or -not $branch) {
        throw 'Could not determine the current Git branch; refusing to purge.'
    }

    $changes = & $gitCommand.Source status --porcelain
    if ($LASTEXITCODE -ne 0) {
        throw 'Could not inspect Git status; refusing to purge.'
    }
    if ($changes) {
        throw 'Git working tree is not clean. Commit, stash, or otherwise preserve changes before running Phase 4.'
    }

    $upstream = (& $gitCommand.Source rev-parse --abbrev-ref --symbolic-full-name '@{upstream}').Trim()
    if ($LASTEXITCODE -ne 0 -or -not $upstream) {
        throw "Branch '$branch' has no configured upstream; refusing to rebase or purge."
    }

    $upstreamParts = $upstream -split '/', 2
    if ($upstreamParts.Count -ne 2) {
        throw "Could not identify the remote and branch from upstream '$upstream'."
    }

    $dockerPath = $dockerCommand.Source
    $engineVersion = & $dockerPath info --format '{{.ServerVersion}}' 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $engineVersion) {
        throw 'Docker Engine is unavailable. Start Docker Desktop, then retry Phase 4.'
    }

    $composeArgs = @('--project-name', $composeProject)
    $envFile = Join-Path $projectRoot '.env'
    if (Test-Path -LiteralPath $envFile -PathType Leaf) {
        $composeArgs += @('--env-file', $envFile)
    }
    $composeArgs += @('-f', $composeFile)

    $expectedComposeFile = [IO.Path]::GetFullPath($composeFile)
    $containerIds = @(& $dockerPath ps -aq --filter "label=com.docker.compose.project=$composeProject")
    if ($LASTEXITCODE -ne 0) {
        throw 'Could not inspect Compose containers; refusing to purge.'
    }

    $demoContainerIds = @()
    foreach ($containerId in $containerIds) {
        $container = (& $dockerPath inspect $containerId | ConvertFrom-Json)[0]
        $labels = $container.Config.Labels
        $configFiles = @($labels.'com.docker.compose.project.config_files' -split ',')
        if ($configFiles -notcontains $expectedComposeFile) {
            throw "Compose project '$composeProject' also contains container '$($container.Name)' from another configuration; refusing to remove shared project resources."
        }
        $demoContainerIds += $container.Id
    }

    $networkIds = @(& $dockerPath network ls -q --filter "label=com.docker.compose.project=$composeProject")
    if ($LASTEXITCODE -ne 0) {
        throw 'Could not inspect Compose networks; refusing to purge.'
    }
    foreach ($networkId in $networkIds) {
        $network = (& $dockerPath network inspect $networkId | ConvertFrom-Json)[0]
        if ($network.Labels.'com.docker.compose.network' -ne 'splunk-net') {
            throw "Compose project '$composeProject' contains unexpected network '$($network.Name)'; refusing to remove shared project resources."
        }
        foreach ($attachedContainerId in $network.Containers.PSObject.Properties.Name) {
            if ($demoContainerIds -notcontains $attachedContainerId) {
                throw "Network '$($network.Name)' is used by a container outside this demo; refusing to remove it."
            }
        }
    }

    $volumeIds = @(& $dockerPath volume ls -q --filter "label=com.docker.compose.project=$composeProject")
    if ($LASTEXITCODE -ne 0) {
        throw 'Could not inspect Compose volumes; refusing to purge.'
    }
    $configuredVolumes = @(& $dockerPath compose @composeArgs config --volumes)
    if ($LASTEXITCODE -ne 0) {
        throw 'Could not resolve Compose volumes; refusing to purge.'
    }
    if ($volumeIds.Count -gt 0 -and $configuredVolumes.Count -eq 0) {
        throw "Compose project '$composeProject' has volumes that are not declared by this configuration; inspect them before removal."
    }
    foreach ($volumeId in $volumeIds) {
        $volume = (& $dockerPath volume inspect $volumeId | ConvertFrom-Json)[0]
        if ($configuredVolumes -notcontains $volume.Labels.'com.docker.compose.volume') {
            throw "Compose project '$composeProject' contains volume '$($volume.Name)' not declared by this configuration; refusing to remove it."
        }
    }

    if (-not $PSCmdlet.ShouldProcess(
        "Git branch '$branch' and Docker Compose project '$composeProject'",
        "Rebase onto '$upstream' and remove this demo's containers, network, and declared volumes"
    )) {
        return
    }

    Write-Host "Fetching upstream $upstream..."
    & $gitCommand.Source fetch $upstreamParts[0] $upstreamParts[1]
    if ($LASTEXITCODE -ne 0) {
        throw "Could not fetch '$upstream'; Docker resources were not removed."
    }

    Write-Host "Rebasing '$branch' onto '$upstream'..."
    & $gitCommand.Source rebase $upstream
    if ($LASTEXITCODE -ne 0) {
        throw "Rebase onto '$upstream' failed. Resolve the Git state before retrying; Docker resources were not removed."
    }

    Write-Host "Removing Docker Compose resources for '$composeProject'..."
    & $dockerPath compose @composeArgs down --volumes --remove-orphans
    if ($LASTEXITCODE -ne 0) {
        throw "Git rebase succeeded, but Docker Compose purge failed. Re-run Phase 4 after inspecting project '$composeProject'."
    }

    Write-Host "Phase 4 complete. Git branch '$branch' is rebased onto '$upstream'; demo Compose resources have been removed."
    Write-Host 'The Splunk image and host-side project files were retained.'
}
finally {
    Pop-Location
}
