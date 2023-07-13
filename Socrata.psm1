<#
    Socrata-PowerShell
#>

#Requires -Version 5.1

class SocrataClient {
    [String][ValidatePattern("^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])$")]$Domain
    [PSCredential] hidden $Auth

    SocrataClient ([String]$Domain) {
        $this.Domain = $Domain
        $this.Auth = $this.GetAuthFromEnvironment()
    }

    SocrataClient ([String]$Domain, [PSCredential]$Auth) {
        $this.Domain = $Domain
        $this.Auth = if (-not $Auth) { $this.GetAuthFromEnvironment() } else { $Auth }
    }

    [String]GetAuthFromEnvironment() {
        Write-Debug "Failed to obtain Socrata credentials from parameter; looking up environment variables SOCRATA_USERNAME and SOCRATA_PASSWORD"
        $SocrataUsername = $Env:SOCRATA_USERNAME
        $SocrataPassword = ConvertTo-SecureString -String $Env:SOCRATA_PASSWORD -AsPlainText -Force

        if (-not $SocrataUsername -or -not $SocrataPassword) {
            throw "Failed to obtain Socrata credentials from parameters or from environment variables SOCRATA_USERNAME and SOCRATA_PASSWORD"
        } else {
            Write-Warning "Obtained credentials from environment variables SOCRATA_USERNAME and SOCRATA_PASSWORD"
        }
        return New-Object PSCredential($SocrataUsername, $SocrataPassword)
    }

    [String]GetAuthString() {
        [String]$Base64EncodedAuth = [System.Convert]::ToBase64String(
            [System.Text.Encoding]::UTF8.GetBytes("$($this.Auth.UserName):$($this.Auth.GetNetworkCredential().Password)")
        )
        return $Base64EncodedAuth
    }

    [PSCustomObject]SendRequest([String]$Method, [String]$Route, [Hashtable]$Body) {
        $Url = "https://$($this.Domain)$Route"
        $AuthString = $this.GetAuthString()
        $Headers = @{ "Authorization" = "Basic $($this.GetAuthString())" }
        $RequestBody = if ($Body) { ConvertTo-Json -InputObject $Body -Compress } else { $null }

        Write-Debug "Sending $Method request to URL: $Url"
        [PSCustomObject]$ResponseJson = Invoke-RestMethod `
            -Method $Method `
            -Uri $Url `
            -Headers $Headers `
            -ContentType "application/json" `
            -Body $RequestBody
        return $ResponseJson
    }

    [PSCustomObject]SendRequest([String]$Method, [String]$Route) {
        return $this.SendRequest($Method, $Route, $null)
    }

    [PSCustomObject]SendFile(
        [String]$Route,
        [String]$ContentType,
        [String]$Filepath,
        [Int64]$TimeoutSec
    ) {
        $Url = "https://$($this.Domain)$Route"
        $AuthString = $this.GetAuthString()
        $Headers = @{ "Authorization" = "Basic $($this.GetAuthString())" }

        Write-Debug "Sending file to URL: $Url"
        [PSCustomObject]$ResponseJson = Invoke-RestMethod `
            -Method "Post" `
            -Uri $Url `
            -Headers $Headers `
            -ContentType $ContentType `
            -InFile $Filepath `
            -TimeoutSec $TimeoutSec
        return $ResponseJson
    }

    [PSCustomObject]NewRevision([String]$Name) {
        $Route = "/api/publishing/v1/revision"
        $Body = @{
            "metadata" = @{
                "name" = $Name
            }
        }

        Write-Verbose "Creating new revision: $Route"
        $ResponseJson = $this.SendRequest("Post", $Route, $Body)
        return $ResponseJson
    }

    [PSCustomObject]OpenRevision([String]$DatasetId, [String]$Type) {
        $Route = "/api/publishing/v1/revision/$DatasetId"
        $Body = @{
            "action" = @{ "type" = $Type }
        }

        Write-Verbose "Opening revision: $Route"
        $ResponseJson = $this.SendRequest("Post", $Route, $Body)
        return $ResponseJson
    }

    [PSCustomObject]SetAudience([String]$DatasetId, [Int64]$RevisionId, [String]$Audience) {
        $Route = "/api/publishing/v1/revision/$DatasetId/$RevisionId"
        $Body = @{
            "permissions" = @{
                "scope" = $Audience
            }
        }

        Write-Verbose "Setting audience: $Route"
        $ResponseJson = $this.SendRequest("Put", $Route, $Body)
        return $ResponseJson
    }

    [PSCustomObject]AddSource([String]$DatasetId, [Int64]$RevisionId) {
        $Route = "/api/publishing/v1/revision/$DatasetId/$RevisionId/source"
        $Body = @{
            "source_type"   = @{
                "type"     = "upload"
                "filename" = "filename"  # This name is arbitrary and doesn't matter
            }
            "parse_options" = @{
                "parse_source" = "true"
            }
        }

        Write-Verbose "Creating new source: $Route"
        $ResponseJson = $this.SendRequest("Post", $Route, $Body)
        return $ResponseJson
    }

    [PSCustomObject]AddUpload([String]$SourceId, [String]$Filepath, [String]$Filetype) {
        $Route = "/api/publishing/v1/source/$SourceId"
        $ContentTypeMappings = @{
            "csv"       = "text/csv"
            "tsv"       = "text/tab-separated-values"
            "xls"       = "application/vnd.ms-excel"
            "xlsx"      = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
            "shapefile" = "application/zip"
            "zip"       = "application/zip"
            "kml"       = "application/vnd.google-earth.kml+xml"
            "kmz"       = "application/vnd.google-earth.kmz"
            "geojson"   = "application/vnd.geo+json"
            "json"      = "application/vnd.geo+json"
        }
        if (-not $Filetype) {
            Write-Verbose "No filetype specified; attempting to infer content type from extension"
            $FileExtension = [System.IO.Path]::GetExtension($Filepath).ToLower().Substring(1)
            $ContentType = $ContentTypeMappings.$FileExtension
            Write-Warning "Inferred content type '$ContentType' from extension '$FileExtension'"
        } else {
            $ContentType = $ContentTypeMappings.$Filetype
        }
        $TimeoutSec = 60 * 60 * 24

        # Send request and return response JSON object
        Write-Verbose "Uploading file to source: $Route"
        $ResponseJson = $this.SendFile($Route, $ContentType, $Filepath, $TimeoutSec)
        return $ResponseJson
    }

    [Boolean]AssertSchemaSucceeded([Int64]$SourceId, [Int64]$InputSchemaId) {
        $Route = "/api/publishing/v1/source/$SourceId/schema/$InputSchemaId/output/latest"

        Write-Verbose "Checking whether dataset has finished processing: $Route"
        $ResponseJson = $this.SendRequest("Get", $Route)

        # Determine whether schema finished processing
        $SchemaFinishedProcessing = -not [String]::IsNullOrEmpty($ResponseJson.resource.finished_at)

        # Determine whether all columns processed without errors
        $NoColumnsFailed = $true
        foreach ($Column in $ResponseJson.resource.output_columns) {
            $ColumnFailed = -not [String]::IsNullOrEmpty($Column.transform.failed_at)
            if ($ColumnFailed) {
                $NoColumnsFailed = $false
                break
            }
        }

        # Return Boolean representing whether schema finished processing with no column errors
        $SchemaSucceeded = $SchemaFinishedProcessing -and $NoColumnsFailed
        if (-not $SchemaSucceeded) {
            throw "Dataset has not yet finished processing"
        }
        return $SchemaSucceeded
    }

    [PSObject]PublishRevision([String]$DatasetId, [Int64]$RevisionId) {
        $Route = "/api/publishing/v1/revision/$DatasetId/$RevisionId/apply"
        $Body = @{ "resource" = @{ "id" = $RevisionId } }

        Write-Verbose "Publishing revision: $Route"
        $ResponseJson = $this.SendRequest("Put", $Route, $Body)
        return $ResponseJson
    }

}

function Wait-ForSuccess {
    <#
        .SYNOPSIS
            Try and retry a function call at a specified interval until it completes successfully.
    #>
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([PSCustomObject])]
    Param(
        # Function call to try
        [Parameter(Mandatory = $true)][Action]$Action,
        # Length of interval (in seconds) to wait between attempts
        [Parameter(Mandatory = $false)][Int16]$Interval = 10,
        # Maximum number of retries to attempt before giving up
        [Parameter(Mandatory = $false)][Int16]$MaxAttempts = 8640
    )
    Process {
        $Attempts = 1
        $ErrorActionPreferenceToRestore = $ErrorActionPreference
        $ErrorActionPreference = "Stop"

        do {
            Write-Verbose "Attempt $Attempts of $MaxAttempts"
            try {
                $Result = $Action.Invoke()
                break
            }
            catch [Exception] {
                Write-Verbose $_.Exception.Message
            }

            # Retry after $Interval seconds
            $Attempts++
            if ($Attempts -le $MaxAttempts) {
                Write-Verbose "Retrying in $Interval seconds..."
                Start-Sleep $Interval
            }
            else {
                $ErrorActionPreference = $ErrorActionPreferenceToRestore
                Write-Error $_.Exception.Message
            }
        } while ($Attempts -le $MaxAttempts)
        $ErrorActionPreference = $ErrorActionPreferenceToRestore

        $Result
    }
}

function Complete-Revision {
    <#
        .SYNOPSIS
            Complete a revision publication cycle on a Socrata domain.

        .OUTPUTS
            String
    #>
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([String])]
    Param(
        # Socrata client instance
        [Parameter(Mandatory = $true)][SocrataClient]$Client,
        # Unique identifier (4x4) for a Socrata dataset
        [Parameter(Mandatory = $true)][ValidatePattern("^\w{4}-\w{4}$")][String]$DatasetId,
        # Revision object
        [Parameter(Mandatory = $true)][PSObject]$Revision,
        # Path representing the data file to upload
        [Parameter(Mandatory = $true)][ValidateScript({ Test-Path $_ })][String]$Filepath,
        # Filetype for the data file to upload
        [Parameter(Mandatory = $false)][ValidateSet("csv", "tsv", "xls", "xlsx", "shapefile", "kml", "geojson", "")][String]$Filetype = $null,
        # Whether to publish the dataset or leave it as an unpublished revision
        [Parameter(Mandatory = $false)][Boolean]$Publish = $true,
        # Activity from which this function was called
        [Parameter(Mandatory = $false)][String]$Activity = $MyInvocation.MyCommand
    )
    Process {
        # Initialize client
        $Client = New-Object SocrataClient -ArgumentList $Domain, $Credentials

        # Get values from revision
        [Int64]$RevisionId = $Revision.resource.revision_seq
        [String]$RevisionUrl = "https://$Domain/d/$DatasetId/revisions/$RevisionId"

        # Create source on revision
        $Status = "Creating source..."
        Write-Progress -Activity $Activity -Status $Status -PercentComplete 20
        [PSObject]$Source = $Client.AddSource($DatasetId, $RevisionId)
        [Int64]$SourceId = $Source.resource.id

        # Upload file to source
        $Status = "Uploading file $Filepath..."
        Write-Progress -Activity $Activity -Status $Status -PercentComplete 40
        [PSObject]$Upload = $Client.AddUpload($SourceId, $Filepath, $Filetype)

        # Get latest input schema based on highest ID
        try {
            [Array]$SortedInputSchemas = $Upload.resource.schemas | Sort-Object `
                -Property "id" `
                -Descending
            [Int64]$LatestInputSchemaId = $SortedInputSchemas[0].id
        }
        catch [Exception] {
            throw "Failed to obtain ID for latest input schema; halting execution"
        }

        # Wait for schema to finish processing
        $Status = "Processing data..."
        Write-Progress -Activity $Activity -Status $Status -PercentComplete 60
        [Boolean]$SchemaSucceeded = Wait-ForSuccess `
            -Action { $Client.AssertSchemaSucceeded($SourceId, $LatestInputSchemaId) } `
            -ErrorAction "Stop"

        # Publish revision
        if ($Publish -eq $true) {
            $Status = "Publishing revision..."
            Write-Progress -Activity $Activity -Status $Status -PercentComplete 80
            [PSObject]$PublishedRevision = $Client.PublishRevision($DatasetId, $RevisionId)
        }

        # Return revision URL
        $Status = "Complete: $RevisionUrl"
        Write-Progress -Activity $Activity -Status $Status -PercentComplete 100
        $RevisionUrl
    }
}

function New-Dataset {
    <#
        .SYNOPSIS
            Create a new dataset on a Socrata domain by uploading a file.

        .OUTPUTS
            String
    #>
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([String])]
    Param(
        # URL for a Socrata domain
        [Parameter(Mandatory = $true)][String]$Domain,
        # Name for the new dataset
        [Parameter(Mandatory = $true)][String]$Name,
        # Path representing the data file to upload
        [Parameter(Mandatory = $true)][ValidateScript({ Test-Path $_ })][String]$Filepath,
        # Filetype for the data file to upload
        [Parameter(Mandatory = $false)][ValidateSet("csv", "tsv", "xls", "xlsx", "shapefile", "kml", "geojson", "")][String]$Filetype = $null,
        # Audience for published dataset
        [Parameter(Mandatory = $false)][ValidateSet("private", "site", "public")][String]$Audience = "private",
        # Whether to publish the dataset or leave it as an unpublished revision
        [Parameter(Mandatory = $false)][Boolean]$Publish = $true,
        # Socrata credentials for authentication
        [Parameter(Mandatory = $false)][PSCredential]$Credentials = $null
    )
    Process {
        # Initialize client
        $Client = New-Object SocrataClient -ArgumentList $Domain, $Credentials

        # Create revision
        $Status = "Creating revision..."
        Write-Progress -Activity $MyInvocation.MyCommand -Status $Status -PercentComplete 1
        [PSObject]$Revision = $Client.NewRevision($Name)
        [String]$DatasetId = $Revision.resource.fourfour
        [Int64]$RevisionId = $Revision.resource.revision_seq
        [String]$RevisionUrl = "https://$Domain/d/$DatasetId/revisions/$RevisionId"

        # Set audience on revision
        [PSObject]$Revision = $Client.SetAudience($DatasetId, $RevisionId, $Audience)

        # Complete revision cycle and return revision URL
        Complete-Revision `
            -Client $Client `
            -DatasetId $DatasetId `
            -Revision $Revision `
            -Filepath $Filepath `
            -Filetype $Filetype `
            -Publish $Publish `
            -Activity $MyInvocation.MyCommand
    }
}

function Update-Dataset {
    <#
        .SYNOPSIS
            Update an existing dataset on a Socrata domain by uploading a file.

        .OUTPUTS
            String
    #>
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([String])]
    Param(
        # URL for a Socrata domain
        [Parameter(Mandatory = $true)][String]$Domain,
        # Unique identifier (4x4) for a Socrata dataset
        [Parameter(Mandatory = $true)][ValidatePattern("^\w{4}-\w{4}$")][String]$DatasetId,
        # Revision type
        [Parameter(Mandatory = $true)][ValidateSet("update", "replace", "delete")][String]$Type,
        # Path representing the data file to upload
        [Parameter(Mandatory = $true)][ValidateScript({ Test-Path $_ })][String]$Filepath,
        # Filetype for the data file to upload
        [Parameter(Mandatory = $false)][ValidateSet("csv", "tsv", "xls", "xlsx", "shapefile", "kml", "kmz", "geojson", "")][String]$Filetype = $null,
        # Whether to publish the dataset or leave it as an unpublished revision
        [Parameter(Mandatory = $false)][Boolean]$Publish = $true,
        # Socrata credentials for authentication
        [Parameter(Mandatory = $false)][PSCredential]$Credentials = $null
    )
    Process {
        # Initialize client
        $Client = New-Object SocrataClient -ArgumentList $Domain, $Credentials

        # Create revision
        $Status = "Creating revision..."
        Write-Progress -Activity $MyInvocation.MyCommand -Status $Status -PercentComplete 1
        [PSObject]$Revision = $Client.OpenRevision($DatasetId, $Type)
        [Int64]$RevisionId = $Revision.resource.revision_seq
        [String]$RevisionUrl = "https://$Domain/d/$DatasetId/revisions/$RevisionId"

        # Complete revision cycle and return revision URL
        Complete-Revision `
            -Client $Client `
            -DatasetId $DatasetId `
            -Revision $Revision `
            -Filepath $Filepath `
            -Filetype $Filetype `
            -Publish $Publish `
            -Activity $MyInvocation.MyCommand
    }
}

function Get-Metadata {
    <#
        .SYNOPSIS
            Get the metadata for a Socrata asset and return the response JSON.

        .OUTPUTS
            PSObject
    #>
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([PSObject])]
    Param(
        # URL for a Socrata domain
        [Parameter(Mandatory = $true)][String]$Domain,
        # Unique identifier (4x4) for an existing Socrata dataset
        [Parameter(Mandatory = $true)][ValidatePattern("^\w{4}-\w{4}$")][String]$DatasetId,
        # Socrata credentials for authentication
        [Parameter(Mandatory = $false)][PSCredential]$Credentials = $null
    )
    Process {
        $Client = New-Object SocrataClient -ArgumentList $Domain, $Credentials
        $Route = "/api/views/metadata/v1/$DatasetId"

        Write-Verbose "Getting metadata: $Route"
        $ResponseJson = $Client.SendRequest("Get", $Route)
        $ResponseJson
    }
}

function Update-Metadata {
    <#
        .SYNOPSIS
            Update the metadata for a Socrata asset and return the response JSON.

        .OUTPUTS
            PSObject
    #>
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([PSObject])]
    Param(
        # URL for a Socrata domain
        [Parameter(Mandatory = $true)][String]$Domain,
        # Unique identifier (4x4) for an existing Socrata dataset
        [Parameter(Mandatory = $true)][ValidatePattern("^\w{4}-\w{4}$")][String]$DatasetId,
        # Object containing metadata fields to use in updating the asset
        [Parameter(Mandatory = $true)][PSObject]$Fields,
        # Whether to simply perform validation on the input fields without modifying the asset
        [Parameter(Mandatory = $false)][Boolean]$ValidateOnly = $false,
        # Whether to perform strict validation on the input fields
        [Parameter(Mandatory = $false)][Boolean]$Strict = $false,
        # Socrata credentials for authentication
        [Parameter(Mandatory = $false)][PSCredential]$Credentials = $null
    )
    Process {
        $Client = New-Object SocrataClient -ArgumentList $Domain, $Credentials
        $BaseRoute = "/api/views/metadata/v1/$DatasetId"
        $QueryString = "validateOnly=$ValidateOnly&strict=$Strict"
        $Route = "${BaseRoute}?${QueryString}"

        Write-Verbose "Updating metadata: $Route"
        $ResponseJson = $Client.SendRequest("Patch", $Route, $Fields)
        $ResponseJson
    }
}
