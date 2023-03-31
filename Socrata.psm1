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

        .PARAMETER Action
            Function call to try.

        .PARAMETER Interval
            Length of interval (in seconds) to wait between attempts.

        .PARAMETER MaxAttempts
            Maximum number of retries to attempt before giving up.
    #>
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([PSCustomObject])]
    Param(
        [Parameter(Mandatory = $true)][Action]$Action,
        [Parameter(Mandatory = $false)][Int16]$Interval = 10,
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

function New-Dataset {
    <#
        .SYNOPSIS
            Create a new dataset on a Socrata domain by uploading a file.

        .PARAMETER Domain
            URL for a Socrata domain.

        .PARAMETER Name
            Name for the new dataset.

        .PARAMETER Filepath
            Path representing the data file to upload.

        .PARAMETER Filetype
            Filetype for the data file to upload ("csv", "tsv", "xls", "xlsx", "shapefile", "kml",
            or "geojson").

        .PARAMETER Audience
            Audience for published dataset: "private", "site", or "public".

        .PARAMETER Publish
            Whether to publish the dataset or leave it as an unpublished revision.

        .PARAMETER Credentials
            Socrata credentials for authentication.

        .OUTPUTS
            String
    #>
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([String])]
    Param(
        [Parameter(Mandatory = $true)][String]$Domain,
        [Parameter(Mandatory = $true)][String]$Name,
        [Parameter(Mandatory = $true)][ValidateScript({ Test-Path $_ })][String]$Filepath,
        [Parameter(Mandatory = $false)][ValidateSet("csv", "tsv", "xls", "xlsx", "shapefile", "kml", "geojson")][String]$Filetype = $null,
        [Parameter(Mandatory = $false)][ValidateSet("private", "site", "public")][String] `
            $Audience = "private",
        [Parameter(Mandatory = $false)][Boolean]$Publish = $true,
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

        # Create source on revision
        $Status = "Creating source..."
        Write-Progress -Activity $MyInvocation.MyCommand -Status $Status -PercentComplete 20
        [PSObject]$Source = $Client.AddSource($DatasetId, $RevisionId)
        [Int64]$SourceId = $Source.resource.id

        # Upload file to source
        $Status = "Uploading file $Filepath..."
        Write-Progress -Activity $MyInvocation.MyCommand -Status $Status -PercentComplete 40
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
        Write-Progress -Activity $MyInvocation.MyCommand -Status $Status -PercentComplete 60
        [Boolean]$SchemaSucceeded = Wait-ForSuccess `
            -Action { $Client.AssertSchemaSucceeded($SourceId, $LatestInputSchemaId) } `
            -ErrorAction "Stop"

        # Publish revision
        if ($Publish -eq $true) {
            $Status = "Publishing revision..."
            Write-Progress -Activity $MyInvocation.MyCommand -Status $Status -PercentComplete 80
            [PSObject]$PublishedRevision = $Client.PublishRevision($DatasetId, $RevisionId)
        }

        # Return revision URL
        $Status = "Complete: $RevisionUrl"
        Write-Progress -Activity $MyInvocation.MyCommand -Status $Status -PercentComplete 100
        $RevisionUrl
    }
}

function Update-Dataset {
    <#
        .SYNOPSIS
            Update an existing dataset on a Socrata domain by uploading a file.

        .PARAMETER Domain
            URL for a Socrata domain.

        .PARAMETER DatasetId
            Unique identifier (4x4) for a Socrata dataset.

        .PARAMETER Type
            Revision type ("update", "replace", or "delete").

        .PARAMETER Filepath
            Path representing the data file to upload.

        .PARAMETER Filetype
            Filetype for the data file to upload ("csv", "tsv", "xls", "xlsx", "shapefile", "kml",
            "kmz", or "geojson").

        .PARAMETER Publish
            Whether to publish the dataset or leave it as an unpublished revision.

        .PARAMETER Credentials
            Socrata credentials for authentication.

        .OUTPUTS
            String
    #>
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([String])]
    Param(
        [Parameter(Mandatory = $true)][String]$Domain,
        [Parameter(Mandatory = $true)][ValidatePattern("^\w{4}-\w{4}$")][String]$DatasetId,
        [Parameter(Mandatory = $true)][ValidateSet("update", "replace", "delete")][String]$Type,
        [Parameter(Mandatory = $true)][ValidateScript({ Test-Path $_ })][String]$Filepath,
        [Parameter(Mandatory = $false)][ValidateSet("csv", "tsv", "xls", "xlsx", "shapefile", "kml", "kmz", "geojson")][String]$Filetype = $null,
        [Parameter(Mandatory = $false)][Boolean]$Publish = $true,
        [Parameter(Mandatory = $false)][PSCredential]$Credentials = $null
    )
    Process {
        # Get credentials
        $Credentials = Get-SocrataCredentials -Credentials $Credentials -ErrorAction "Stop"

        # Create revision
        Write-Progress `
            -Activity $MyInvocation.MyCommand `
            -Status "Creating revision..." `
            -PercentComplete 1
        [PSObject]$Revision = Open-Revision `
            -Domain $Domain `
            -DatasetId $DatasetId `
            -Type $Type `
            -Credentials $Credentials `
            -ErrorAction "Stop"
        [Int64]$RevisionId = $Revision.resource.revision_seq
        [String]$RevisionUrl = "https://$Domain/d/$DatasetId/revisions/$RevisionId"

        # Create source on revision
        Write-Progress `
        -Activity $MyInvocation.MyCommand `
        -Status "Creating source..." `
        -PercentComplete 20
        [PSObject]$Source = Add-Source `
            -Domain $Domain `
            -DatasetId $DatasetId `
            -RevisionId $RevisionId `
            -Credentials $Credentials `
            -ErrorAction "Stop"
        [Int64]$SourceId = $Source.resource.id

        # Upload file to source
        Write-Progress `
            -Activity $MyInvocation.MyCommand `
            -Status "Uploading file $Filepath..." `
            -PercentComplete 40
        if (-not $Filetype) {
            [PSObject]$Upload = Add-Upload `
                -Domain $Domain `
                -SourceId $SourceId `
                -Filepath $Filepath `
                -Credentials $Credentials `
                -ErrorAction "Stop"
        }
        else {
            [PSObject]$Upload = Add-Upload `
                -Domain $Domain `
                -SourceId $SourceId `
                -Filepath $Filepath `
                -Filetype $Filetype `
                -Credentials $Credentials `
                -ErrorAction "Stop"
        }

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
        Write-Progress `
            -Activity $MyInvocation.MyCommand `
            -Status "Processing data..." `
            -PercentComplete 60
        [Boolean]$SchemaSucceeded = Wait-ForSuccess `
            -Action { Assert-SchemaSucceeded `
                -Domain $Domain `
                -SourceId $SourceId `
                -InputSchemaId $LatestInputSchemaId `
                -Credentials $Credentials `
                -ErrorAction "Stop" } `
            -ErrorAction "Stop"

        # Publish revision
        if ($Publish -eq $true) {
            Write-Progress `
                -Activity $MyInvocation.MyCommand `
                -Status "Publishing revision..." `
                -PercentComplete 80
            [PSObject]$PublishedRevision = Publish-Revision `
                -Domain $Domain `
                -DatasetId $DatasetId `
                -RevisionId $RevisionId `
                -Credentials $Credentials
        }

        Write-Progress `
            -Activity $MyInvocation.MyCommand `
            -Status "Complete: $RevisionUrl" `
            -PercentComplete 100
        $RevisionUrl
    }
}

function Get-Metadata {
    <#
        .SYNOPSIS
            Get the metadata for a Socrata asset and return the response JSON.

        .PARAMETER Domain
            URL for a Socrata domain.

        .PARAMETER DatasetId
            Unique identifier (4x4) for an existing Socrata dataset.

        .OUTPUTS
            PSObject
    #>
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([PSObject])]
    Param(
        [Parameter(Mandatory = $true)][String]$Domain,
        [Parameter(Mandatory = $true)][ValidatePattern("^\w{4}-\w{4}$")][String]$DatasetId,
        [Parameter(Mandatory = $false)][PSCredential]$Credentials = $null
    )
    Process {
        # Get credentials
        $Credentials = Get-SocrataCredentials -Credentials $Credentials -ErrorAction "Stop"
        $AuthString = Convert-SocrataCredentialsToAuthString `
            -Credentials $Credentials `
            -ErrorAction "Stop"

        # Prepare HTTP request to get metadata
        $MetadataUrl = "https://$Domain/api/views/metadata/v1/$DatasetId"
        $Headers = @{ "Authorization" = "Basic $AuthString" }

        # Send request and return response JSON object
        Write-Verbose "Getting metadata: $MetadataUrl"
        $ResponseJson = Invoke-RestMethod `
            -Method "Get" `
            -Uri $MetadataUrl `
            -Headers $Headers `
            -ContentType "application/json"
        $ResponseJson
    }
}

function Update-Metadata {
    <#
        .SYNOPSIS
            Update the metadata for a Socrata asset and return the response JSON.

        .PARAMETER Domain
            URL for a Socrata domain.

        .PARAMETER DatasetId
            Unique identifier (4x4) for an existing Socrata dataset.

        .PARAMETER Fields
            Object containing metadata fields to use in updating the asset.

        .PARAMETER ValidateOnly
            Whether to simply perform validation on the input fields without modifying the asset.
            The asset's metadata is then returned as it would be if it had been modified, along
            with a list of errors and warnings.

        .PARAMETER Strict
            Whether to perform strict validation on the input fields.

        .OUTPUTS
            PSObject
    #>
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([PSObject])]
    Param(
        [Parameter(Mandatory = $true)][String]$Domain,
        [Parameter(Mandatory = $true)][ValidatePattern("^\w{4}-\w{4}$")][String]$DatasetId,
        [Parameter(Mandatory = $true)][PSObject]$Fields,
        [Parameter(Mandatory = $false)][Boolean]$ValidateOnly = $false,
        [Parameter(Mandatory = $false)][Boolean]$Strict = $false,
        [Parameter(Mandatory = $false)][PSCredential]$Credentials = $null
    )
    Process {
        # Get credentials
        $Credentials = Get-SocrataCredentials -Credentials $Credentials -ErrorAction "Stop"
        $AuthString = Convert-SocrataCredentialsToAuthString `
            -Credentials $Credentials `
            -ErrorAction "Stop"

        # Prepare HTTP request to update metadata
        $BaseMetadataUrl = "https://$Domain/api/views/metadata/v1/$DatasetId"
        $QueryString = "validateOnly=$ValidateOnly&strict=$Strict"
        $MetadataUrl = "${BaseMetadataUrl}?${QueryString}"
        $Headers = @{ "Authorization" = "Basic $AuthString" }
        $Body = $Fields | ConvertTo-Json -Compress

        # Send request and return response JSON object
        Write-Verbose "Updating metadata: $MetadataUrl"
        $ResponseJson = Invoke-RestMethod `
            -Method "Patch" `
            -Uri $MetadataUrl `
            -Headers $Headers `
            -ContentType "application/json" `
            -Body $Body
        $ResponseJson
    }
}
