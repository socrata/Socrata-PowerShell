<#
    Socrata.psm1
#>

# Require PowerShell 5.1 or above
#Requires -Version 5.1

function Get-AuthString {
    <#
        .SYNOPSIS
            Obtain Socrata credentials from the local env variables SOCRATA_USERNAME and
            SOCRATA_PASSWORD, then encode them to base-64 for use in HTTP Basic Auth.

        .OUTPUTS
            String
    #>
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([String])]
    Param()
    Process {
        $SocrataUsername = $Env:SOCRATA_USERNAME
        $SocrataPassword = $Env:SOCRATA_PASSWORD
        if (-not $SocrataUsername -or -not $SocrataPassword) {
            throw "You must set the environment variables SOCRATA_USERNAME and SOCRATA_PASSWORD"
        }
        Write-Host (
            "Obtained Socrata credentials from environment variables SOCRATA_USERNAME and SOCRATA_PASSWORD"
        )

        # Encode credentials for Basic Auth and return
        [String]$Base64EncodedAuth = [Convert]::ToBase64String(
            [Text.Encoding]::ASCII.GetBytes("${SocrataUsername}:${SocrataPassword}")
        )
        $Base64EncodedAuth
    }
}

function New-Revision {
    <#
        .SYNOPSIS
            Create the initial revision of an entirely new dataset.

        .PARAMETER Domain
            URL for a Socrata domain.

        .PARAMETER Name
            Name for the new dataset.

        .PARAMETER AuthString
            Base-64-encoded string representing Socrata credentials to use for authentication.

        .OUTPUTS
            PSObject
    #>
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([PSObject])]
    Param(
        [Parameter(Mandatory = $true)][String]$Domain,
        [Parameter(Mandatory = $true)][String]$Name,
        [Parameter(Mandatory = $true)][String]$AuthString
    )
    Process {
        # Prepare HTTP request to create a revision
        $RevisionUrl = "https://$Domain/api/publishing/v1/revision"
        $Headers = @{ "Authorization" = "Basic $AuthString" }
        $Body = @{
            "metadata" = @{
                "name" = $Name
            }
        } | ConvertTo-Json -Compress

        # Send request and return response JSON object
        Write-Host "Creating new revision: $RevisionUrl"
        $ResponseJson = Invoke-RestMethod `
            -Method "Post" `
            -Uri $RevisionUrl `
            -Headers $Headers `
            -ContentType "application/json" `
            -Body $Body
        $ResponseJson
    }
}

function Open-Revision {
    <#
        .SYNOPSIS
            Open a new revision to an existing Socrata dataset and return the response JSON.

        .PARAMETER Domain
            URL for a Socrata domain.

        .PARAMETER Type
            Revision type ("update" or "replace").

        .PARAMETER DatasetId
            Unique identifier (4x4) for an existing Socrata dataset.

        .PARAMETER AuthString
            Base-64-encoded string representing Socrata credentials to use for authentication.

        .OUTPUTS
            PSObject
    #>
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([PSObject])]
    Param(
        [Parameter(Mandatory = $true)][String]$Domain,
        [Parameter(Mandatory = $true)][ValidatePattern("^\w{4}-\w{4}$")][String]$DatasetId,
        [Parameter(Mandatory = $true)][ValidateSet("update", "replace")][String]$Type,
        [Parameter(Mandatory = $true)][String]$AuthString
    )
    Process {
        # Prepare HTTP request to create a revision
        $RevisionUrl = "https://$Domain/api/publishing/v1/revision/$DatasetId"
        $Headers = @{ "Authorization" = "Basic $AuthString" }
        $Body = @{
            "action" = @{ "type" = $Type }
        } | ConvertTo-Json -Compress

        # Send request and return response JSON object
        Write-Host "Creating new revision: $RevisionUrl"
        $ResponseJson = Invoke-RestMethod `
            -Method "Post" `
            -Uri $RevisionUrl `
            -Headers $Headers `
            -ContentType "application/json" `
            -Body $Body
        $ResponseJson
    }
}

function Set-Audience {
    <#
        .SYNOPSIS
            Set the publication audience for a revision.

        .PARAMETER Domain
            URL for a Socrata domain.

        .PARAMETER DatasetId
            Unique identifier (4x4) for a Socrata dataset.

        .PARAMETER Audience
            Audience for published dataset: "private", "site", or "public".

        .PARAMETER AuthString
            Base-64-encoded string representing Socrata credentials to use for authentication.

        .OUTPUTS
            PSObject
    #>
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([PSObject])]
    Param(
        [Parameter(Mandatory = $true)][String]$Domain,
        [Parameter(Mandatory = $true)][ValidatePattern("^\w{4}-\w{4}$")][String]$DatasetId,
        [Parameter(Mandatory = $true)][ValidateSet("private", "site", "public")][String] `
            $Audience,
        [Parameter(Mandatory = $true)][String]$AuthString
    )
    Process {
        # Prepare HTTP request to set the audience on a revision
        $AudienceUrl = "https://$Domain/api/publishing/v1/revision/$DatasetId/$RevisionId"
        $Headers = @{ "Authorization" = "Basic $AuthString" }
        $Body = @{
            "permissions" = @{
                "scope" = $Audience
            }
        } | ConvertTo-Json -Compress

        # Send request and return response JSON object
        Write-Host "Setting audience: $AudienceUrl"
        $ResponseJson = Invoke-RestMethod `
            -Method "Put" `
            -Uri $AudienceUrl `
            -Headers $Headers `
            -ContentType "application/json" `
            -Body $Body
        $ResponseJson
    }
}

function Add-Source {
    <#
        .SYNOPSIS
            Create a new source on a revision and return the response JSON.

        .PARAMETER Domain
            URL for a Socrata domain.

        .PARAMETER DatasetId
            Unique identifier (4x4) for a Socrata dataset.

        .PARAMETER RevisionId
            Revision number on which to create the source.

        .PARAMETER AuthString
            Base-64-encoded string representing Socrata credentials to use for authentication.

        .OUTPUTS
            PSObject
    #>
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([PSObject])]
    Param(
        [Parameter(Mandatory = $true)][String]$Domain,
        [Parameter(Mandatory = $true)][ValidatePattern("^\w{4}-\w{4}$")][String]$DatasetId,
        [Parameter(Mandatory = $true)][Int64]$RevisionId,
        [Parameter(Mandatory = $true)][String]$AuthString
    )
    Process {
        # Prepare HTTP request to create a source on a revision
        $SourceUrl = "https://$Domain/api/publishing/v1/revision/$DatasetId/$RevisionId/source"
        $Headers = @{ "Authorization" = "Basic $AuthString" }
        $Body = @{
            "source_type"   = @{
                "type"     = "upload"
                "filename" = "filename"  # This name is arbitrary and doesn't matter
            }
            "parse_options" = @{
                "parse_source" = "true"
            }
        } | ConvertTo-Json -Compress

        # Send request and return response JSON object
        Write-Host "Creating new source: $SourceUrl"
        $ResponseJson = Invoke-RestMethod `
            -Method "Post" `
            -Uri $SourceUrl `
            -Headers $Headers `
            -ContentType "application/json" `
            -Body $Body
        $ResponseJson
    }
}

function Add-Upload {
    <#
        .SYNOPSIS
            Upload a file to a source and return the response JSON.

        .PARAMETER Domain
            URL for a Socrata domain.

        .PARAMETER SourceId
            Unique identifier for a source.

        .PARAMETER Filepath
            Path representing the data file to upload.

        .PARAMETER Filetype
            Filetype for the data file to upload ("csv", "tsv", "xls", "xlsx", "shapefile", "kml",
            or "geojson").

        .PARAMETER AuthString
            Base-64-encoded string representing Socrata credentials to use for authentication.

        .PARAMETER TimeoutSec
            Number of seconds to allow before timing out. Optional; defaults to 4 hours to
            allow for very large files.

        .OUTPUTS
            PSObject
    #>
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([PSObject])]
    Param(
        [Parameter(Mandatory = $true)][String]$Domain,
        [Parameter(Mandatory = $true)][Int64]$SourceId,
        [Parameter(Mandatory = $true)][String]$Filepath,
        [Parameter(Mandatory = $false)][ValidateSet("csv", "tsv", "xls", "xlsx", "shapefile", "kml", "geojson")][String]$Filetype = $null,
        [Parameter(Mandatory = $true)][String]$AuthString,
        [Parameter(Mandatory = $false)][Int64]$TimeoutSec = 60 * 60 * 4  # Default: 4 hours
    )
    Process {
        # Determine request Content-Type
        $ContentTypeMappings = @{
            "csv"       = "text/csv"
            "tsv"       = "text/tab-separated-values"
            "xls"       = "application/vnd.ms-excel"
            "xlsx"      = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
            "shapefile" = "application/zip"
            "zip"       = "application/zip"
            "kml"       = "application/vnd.google-earth.kml+xml"
            "kmz"       = "application/vnd.google-earth.kml+xml"
            "geojson"   = "application/vnd.geo+json"
            "json"      = "application/vnd.geo+json"
        }
        if ($null -ne $Filetype -and $Filetype -ne "") {
            $ContentType = $ContentTypeMappings.$Filetype
        }
        else {
            Write-Host "No filetype specified; attempting to infer content type from extension"
            $FileExtension = [System.IO.Path]::GetExtension($Filepath).ToLower().Substring(1)
            $ContentType = $ContentTypeMappings.$FileExtension
            Write-Host "Inferred content type '$ContentType' from extension '$FileExtension'"
        }

        # Prepare HTTP request to upload file to a revision source
        $SourceUploadUrl = "https://$Domain/api/publishing/v1/source/$SourceId"
        $Headers = @{
            "Authorization" = "Basic $AuthString"
        }

        # Send request and return response JSON object
        Write-Host "Uploading file to source: $SourceUploadUrl"
        $ResponseJson = Invoke-RestMethod `
            -Method "Post" `
            -Uri $SourceUploadUrl `
            -Headers $Headers `
            -ContentType $ContentType `
            -InFile $Filepath `
            -TimeoutSec $TimeoutSec
        $ResponseJson
    }
}

function Assert-SchemaSucceeded {
    <#
        .SYNOPSIS
            Assert that an output schema has succeeded in processing. If not, throw an error.

        .PARAMETER Domain
            URL for a Socrata domain.

        .PARAMETER SourceId
            Unique identifier for a source.

        .PARAMETER InputSchemaId
            Unique identifier for an input schema on the source.

        .PARAMETER AuthString
            Base-64-encoded string representing Socrata credentials to use for authentication.

        .OUTPUTS
            Boolean
    #>
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([Boolean])]
    Param(
        [Parameter(Mandatory = $true)][String]$Domain,
        [Parameter(Mandatory = $true)][Int64]$SourceId,
        [Parameter(Mandatory = $true)][Int64]$InputSchemaId,
        [Parameter(Mandatory = $true)][String]$AuthString
    )
    Process {
        # Prepare HTTP request to upload file to a revision source
        $OutputSchemaUrl = "https://$Domain/api/publishing/v1/source/$SourceId/schema/$InputSchemaId/output/latest"
        $Headers = @{ "Authorization" = "Basic $AuthString" }

        # Send request
        Write-Host "Checking whether dataset has finished processing: $OutputSchemaUrl"
        $ResponseJson = Invoke-RestMethod `
            -Method "Get" `
            -Uri $OutputSchemaUrl `
            -Headers $Headers `
            -ContentType "application/json"

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
        $SchemaSucceeded
    }
}

function Publish-Revision {
    <#
        .SYNOPSIS
            Upload a file to a source and return the response JSON.

        .PARAMETER Domain
            URL for a Socrata domain.

        .PARAMETER DatasetId
            Unique identifier (4x4) for a Socrata dataset.

        .PARAMETER RevisionId
            Revision number on which to create the source.

        .PARAMETER AuthString
            Base-64-encoded string representing Socrata credentials to use for authentication.

        .OUTPUTS
            PSObject
    #>
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([PSObject])]
    Param(
        [Parameter(Mandatory = $true)][String]$Domain,
        [Parameter(Mandatory = $true)][ValidatePattern("^\w{4}-\w{4}$")][String]$DatasetId,
        [Parameter(Mandatory = $true)][Int64]$RevisionId,
        [Parameter(Mandatory = $true)][String]$AuthString
    )
    Process {
        # Prepare HTTP request to publish revision
        $PublishUrl = "https://$Domain/api/publishing/v1/revision/$DatasetId/$RevisionId/apply"
        $Headers = @{ "Authorization" = "Basic $AuthString" }
        $Body = @{ "resource" = @{ "id" = $RevisionId } } | ConvertTo-Json -Compress

        # Send request and return response JSON object
        Write-Host "Publishing revision: $PublishUrl"
        $ResponseJson = Invoke-RestMethod `
            -Method "Put" `
            -Uri $PublishUrl `
            -Headers $Headers `
            -ContentType "application/json" `
            -Body $Body
        $ResponseJson
    }
}

function Retry {
    <#
        .SYNOPSIS
            Retry a function call every 30 seconds

        .PARAMETER Action
            Function call to retry.

        .PARAMETER Interval
            Length of interval (in seconds) between attempts.

        .PARAMETER MaxAttempts
            Maximum number of retries to attempt before giving up.
    #>
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([PSCustomObject])]
    Param(
        [Parameter(Mandatory = $true)][Action]$Action,
        [Parameter(Mandatory = $false)][Int16]$Interval = 30,
        [Parameter(Mandatory = $false)][Int16]$MaxAttempts = 2880
    )
    Process {
        $Attempts = 1
        $ErrorActionPreferenceToRestore = $ErrorActionPreference
        $ErrorActionPreference = "Stop"

        do {
            Write-Debug "Attempt $Attempts of $MaxAttempts"
            try {
                $action.Invoke()
                break
            }
            catch [Exception] {
                Write-Host $_.Exception.Message
            }

            # Retry after $Interval seconds
            $Attempts++
            if ($Attempts -le $MaxAttempts) {
                Write-Host "Retrying in $Interval seconds..."
                Start-Sleep $Interval
            }
            else {
                $ErrorActionPreference = $ErrorActionPreferenceToRestore
                Write-Error $_.Exception.Message
            }
        } while ($Attempts -le $MaxAttempts)
        $ErrorActionPreference = $ErrorActionPreferenceToRestore
    }
}

function New-Dataset {
    <#
        .SYNOPSIS
            Create a new dataset draft on a Socrata domain by uploading a file.

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

        .OUTPUTS
            String
    #>
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([PSObject])]
    Param(
        [Parameter(Mandatory = $true)][String]$Domain,
        [Parameter(Mandatory = $true)][String]$Name,
        [Parameter(Mandatory = $true)][ValidateScript({ Test-Path $_ })][String]$Filepath,
        [Parameter(Mandatory = $false)][ValidateSet("csv", "tsv", "xls", "xlsx", "shapefile", "kml", "geojson")][String]$Filetype = $null,
        [Parameter(Mandatory = $false)][ValidateSet("private", "site", "public")][String] `
            $Audience = "private"
    )
    Process {
        # Get auth string
        [String]$AuthString = Get-AuthString -ErrorAction "Stop"

        # Create revision
        [PSObject]$Revision = New-Revision `
            -Domain $Domain `
            -Name $Name `
            -AuthString $AuthString `
            -ErrorAction "Stop"
        [String]$DatasetId = $Revision.resource.fourfour
        [Int64]$RevisionId = $Revision.resource.revision_seq
        [String]$RevisionUrl = "https://$Domain/d/$DatasetId/revisions/$RevisionId"

        # Set audience on revision
        [PSObject]$Revision = Set-Audience `
            -Domain $Domain `
            -DatasetId $DatasetId `
            -Audience $Audience `
            -AuthString $AuthString `
            -ErrorAction "Stop"

        # Create source on revision
        [PSObject]$Source = Add-Source `
            -Domain $Domain `
            -DatasetId $DatasetId `
            -RevisionId $RevisionId `
            -AuthString $AuthString `
            -ErrorAction "Stop"
        [Int64]$SourceId = $Source.resource.id

        # Upload file to source
        if ($null -eq $Filetype -or $Filetype -eq "") {
            [PSObject]$Upload = Add-Upload `
                -Domain $Domain `
                -SourceId $SourceId `
                -Filepath $Filepath `
                -AuthString $AuthString `
                -ErrorAction "Stop"
        }
        else {
            [PSObject]$Upload = Add-Upload `
                -Domain $Domain `
                -SourceId $SourceId `
                -Filepath $Filepath `
                -Filetype $Filetype `
                -AuthString $AuthString `
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
        Retry `
            -Action { Assert-SchemaSucceeded `
                -Domain $Domain `
                -SourceId $SourceId `
                -InputSchemaId $LatestInputSchemaId `
                -AuthString $AuthString `
                -ErrorAction "Stop" } `
            -ErrorAction "Stop"

        # Publish revision
        Publish-Revision `
            -Domain $Domain `
            -DatasetId $DatasetId `
            -RevisionId $RevisionId `
            -AuthString $AuthString
        Write-Host "View publication status: $RevisionUrl"
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
            Revision type ("update" or "replace").

        .PARAMETER Filepath
            Path representing the data file to upload.

        .PARAMETER Filetype
            Filetype for the data file to upload ("csv", "tsv", "xls", "xlsx", "shapefile", "kml",
            or "geojson").

        .OUTPUTS
            String
    #>
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([PSObject])]
    Param(
        [Parameter(Mandatory = $true)][String]$Domain,
        [Parameter(Mandatory = $true)][ValidatePattern("^\w{4}-\w{4}$")][String]$DatasetId,
        [Parameter(Mandatory = $true)][ValidateSet("update", "replace")][String]$Type,
        [Parameter(Mandatory = $true)][ValidateScript({ Test-Path $_ })][String]$Filepath,
        [Parameter(Mandatory = $false)][ValidateSet("csv", "tsv", "xls", "xlsx", "shapefile", "kml", "geojson")][String]$Filetype = $null
    )
    Process {
        # Get auth string
        [String]$AuthString = Get-AuthString -ErrorAction "Stop"

        # Create revision
        [PSObject]$Revision = Open-Revision `
            -Domain $Domain `
            -DatasetId $DatasetId `
            -Type $Type `
            -AuthString $AuthString `
            -ErrorAction "Stop"
        [Int64]$RevisionId = $Revision.resource.revision_seq
        [String]$RevisionUrl = "https://$Domain/d/$DatasetId/revisions/$RevisionId"

        # Create source on revision
        [PSObject]$Source = Add-Source `
            -Domain $Domain `
            -DatasetId $DatasetId `
            -RevisionId $RevisionId `
            -AuthString $AuthString `
            -ErrorAction "Stop"
        [Int64]$SourceId = $Source.resource.id

        # Upload file to source
        if ($null -eq $Filetype -or $Filetype -eq "") {
            [PSObject]$Upload = Add-Upload `
                -Domain $Domain `
                -SourceId $SourceId `
                -Filepath $Filepath `
                -AuthString $AuthString `
                -ErrorAction "Stop"
        }
        else {
            [PSObject]$Upload = Add-Upload `
                -Domain $Domain `
                -SourceId $SourceId `
                -Filepath $Filepath `
                -Filetype $Filetype `
                -AuthString $AuthString `
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
        Retry `
            -Action { Assert-SchemaSucceeded `
                -Domain $Domain `
                -SourceId $SourceId `
                -InputSchemaId $LatestInputSchemaId `
                -AuthString $AuthString `
                -ErrorAction "Stop" } `
            -ErrorAction "Stop"

        # Publish revision
        Publish-Revision `
            -Domain $Domain `
            -DatasetId $DatasetId `
            -RevisionId $RevisionId `
            -AuthString $AuthString
        Write-Host "View publication status: $RevisionUrl"
        $RevisionUrl
    }
}
