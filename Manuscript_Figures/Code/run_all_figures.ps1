param(
    [string]$Image = "docker.io/zafiro/o2_supply_demand_map:r44",
    [int]$NCore = 8,
    [switch]$Offline,
    [switch]$CheckOnly,
    [ValidateSet("TRUE", "FALSE")][string]$RecomputeFixedO2 = "FALSE",
    [ValidateSet("TRUE", "FALSE")][string]$RecomputeInvivoTsne = "FALSE",
    [ValidateSet("TRUE", "FALSE")][string]$ModelDependentOnly = "FALSE",
    [ValidateSet(1, 3, 4)][int]$FirstMainFigure = 1,
    [ValidateSet("TRUE", "FALSE")][string]$ResumeAfterFigure5fDe = "FALSE",
    [ValidateSet("TRUE", "FALSE")][string]$Figure6Smoke = "FALSE"
)

$ErrorActionPreference = "Stop"
$ExpectedImageId = "sha256:32c49db0ad27a0b5832b601ba96e2b72bfc1e2f1ccbf34687f8f596f1f7cdcd5"
$ExpectedManifest = "sha256:32d30d8d3cae9468e466cabeaa7f51cfcc07b4a867ea66aa06c998c141067132"
$ExpectedPlatform = "linux/amd64"
$AnalysisVersion = "publication-r44"
$DefaultImage = "docker.io/zafiro/o2_supply_demand_map:r44"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir "../..")).Path
$ContainerEntry = "/workspace/Manuscript_Figures/Code/run_all_figures_container.sh"
$FetchEntry = "/workspace/Manuscript_Figures/Code/fetch_zenodo_inputs.sh"

if ($NCore -lt 1) {
    throw "-NCore must be a positive integer."
}
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Error @"
Docker is required but is not available on PATH.
Install/start Docker Desktop, then download the locked image with:
  docker pull --platform $ExpectedPlatform $DefaultImage
"@
}
& docker info *> $null
if ($LASTEXITCODE -ne 0) {
    throw "Docker Desktop is installed but its daemon is unavailable."
}
& docker image inspect $Image *> $null
if ($LASTEXITCODE -ne 0) {
    Write-Error @"
Locked analysis image is not available locally: $Image
Download it with:
  docker pull --platform $ExpectedPlatform $DefaultImage
"@
}

$ImageId = (& docker image inspect --format '{{.Id}}' $Image).Trim()
$Platform = (& docker image inspect --format '{{.Os}}/{{.Architecture}}' $Image).Trim()
if ($Platform -ne $ExpectedPlatform) {
    throw "Docker platform mismatch: expected $ExpectedPlatform, observed $Platform."
}
if ($ImageId -ne $ExpectedImageId) {
    $LabelVersion = (& docker image inspect --format '{{index .Config.Labels "org.opencontainers.image.version"}}' $Image).Trim()
    $LabelBase = (& docker image inspect --format '{{index .Config.Labels "org.opencontainers.image.base.digest"}}' $Image).Trim()
    if ($LabelVersion -ne $AnalysisVersion -or $LabelBase -ne $ExpectedManifest) {
        throw "Docker image identity mismatch. Expected $ExpectedImageId; observed $ImageId."
    }
}

$SourceGitSha = "unknown"
if (Get-Command git -ErrorAction SilentlyContinue) {
    $SourceGitSha = (& git -C $RepoRoot rev-parse HEAD).Trim()
}
$RuntimeRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("ltee-oxygen-runtime-" + [guid]::NewGuid())
$RuntimeCache = Join-Path $RuntimeRoot "cache"
$RcppCache = Join-Path $RuntimeRoot "rcpp-cache"
New-Item -ItemType Directory -Path $RuntimeCache, $RcppCache -Force | Out-Null
Set-Content -Path (Join-Path $RuntimeRoot "Rprofile") -Encoding ascii -Value 'options(bitmapType = "cairo", device = "png", warn = 1)'

function Invoke-AnalysisContainer {
    param(
        [ValidateSet("none", "bridge")][string]$Network,
        [string[]]$Command
    )
    $Arguments = @(
        "run", "--rm", "--init",
        "--platform", $ExpectedPlatform,
        "--network", $Network,
        "--workdir", "/workspace",
        "--mount", "type=bind,source=$RepoRoot,target=/workspace",
        "--mount", "type=bind,source=$RuntimeRoot,target=/runtime",
        "--mount", "type=bind,source=$RcppCache,target=/workspace/Model/oxygen/code/O2_supply_demand_MAP/model/.rcpp_cache_o2_supply_demand_map",
        "--env", "LTEE_CONTAINER_RUNTIME_ACTIVE=TRUE",
        "--env", "LTEE_CONTAINER_RUNTIME=docker",
        "--env", "LTEE_CONTAINER_REPO_ROOT=/workspace",
        "--env", "LTEE_ANALYSIS_VERSION=$AnalysisVersion",
        "--env", "LTEE_ANALYSIS_IMAGE_REFERENCE=$Image",
        "--env", "LTEE_ANALYSIS_IMAGE_IDENTITY=$ImageId",
        "--env", "LTEE_SOURCE_GIT_SHA=$SourceGitSha",
        "--env", "HOME=/runtime",
        "--env", "TMPDIR=/runtime/cache",
        "--env", "XDG_CACHE_HOME=/runtime/cache",
        "--env", "R_PROFILE_USER=/runtime/Rprofile",
        "--env", "R_ENVIRON_USER=/dev/null",
        "--env", "PYTHONNOUSERSITE=1",
        "--env", "OMP_NUM_THREADS=1",
        "--env", "OPENBLAS_NUM_THREADS=1",
        "--env", "MKL_NUM_THREADS=1",
        "--env", "VECLIB_MAXIMUM_THREADS=1",
        "--env", "RCPP_PARALLEL_NUM_THREADS=1",
        $Image
    ) + $Command
    & docker @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Container command failed with status $LASTEXITCODE."
    }
}

try {
    if ($CheckOnly) {
        Invoke-AnalysisContainer -Network "none" -Command @("bash", $ContainerEntry, "--check-only")
        exit 0
    }

    $RequiredProbes = @(
        "results/Model_fitting",
        "results/data"
    )
    $Missing = @($RequiredProbes | Where-Object { -not (Test-Path (Join-Path $RepoRoot $_) -PathType Container) })
    if ($Missing.Count -gt 0) {
        if ($Offline) {
            throw "Required publication inputs are missing in offline mode:`n  $($Missing -join "`n  ")"
        }
        Write-Host "Required inputs are missing; invoking the containerized Zenodo fetcher."
        Invoke-AnalysisContainer -Network "bridge" -Command @("bash", $FetchEntry, "--dataset=required")
    }

    $RunArguments = @(
        "bash", $ContainerEntry,
        "--n-core=$NCore",
        "--recompute-fixed-o2=$RecomputeFixedO2",
        "--recompute-invivo-tsne=$RecomputeInvivoTsne",
        "--model-dependent-only=$ModelDependentOnly",
        "--first-main-figure=$FirstMainFigure",
        "--resume-after-figure5f-de=$ResumeAfterFigure5fDe",
        "--figure6-smoke=$Figure6Smoke"
    )
    Invoke-AnalysisContainer -Network "none" -Command $RunArguments
}
finally {
    if (Test-Path $RuntimeRoot) {
        Remove-Item -LiteralPath $RuntimeRoot -Recurse -Force
    }
}
