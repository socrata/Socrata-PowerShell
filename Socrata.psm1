<#
    Socrata-PowerShell
#>

#Requires -Version 5.1

function Convert-SocrataCredentialsToAuthString {
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([String])]
    Param(
        [Parameter(Mandatory = $true)][PSCredential]$Credentials
    )
    Process {
        [String]$Base64EncodedAuth = [System.Convert]::ToBase64String(
            [System.Text.Encoding]::UTF8.GetBytes("$($Credentials.UserName):$($Credentials.Password | ConvertFrom-SecureString -AsPlainText)")
        )
        $Base64EncodedAuth
    }
}

function Get-SocrataCredentials {
    <#
        .SYNOPSIS
            Obtain Socrata credentials from the local env variables SOCRATA_USERNAME and
            SOCRATA_PASSWORD.

        .OUTPUTS
            PSCredential
    #>
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([PSCredential])]
    Param(
        [Parameter(Mandatory = $false)][String]$SocrataUsername = $null,
        [Parameter(Mandatory = $false)][SecureString]$SocrataPassword = $null
    )
    Process {
        if (-not $SocrataUsername -or -not $SocrataPassword) {
            Write-Debug "Credentials not passed or incomplete; looking up environment variables SOCRATA_USERNAME and SOCRATA_PASSWORD"
            $SocrataUsername = $Env:SOCRATA_USERNAME
            $SocrataPassword = $Env:SOCRATA_PASSWORD | ConvertTo-SecureString -AsPlainText -Force

            if (-not $SocrataUsername -or -not $SocrataPassword) {
                throw "Credentials not found or incomplete when looking up environment variables SOCRATA_USERNAME and SOCRATA_PASSWORD"
            }
            else {
                Write-Debug "Obtained credentials from environment variables SOCRATA_USERNAME and SOCRATA_PASSWORD"
            }
        }
        else {
            Write-Debug "Obtained Socrata credentials"
        }

        New-Object PSCredential($SocrataUsername, $SocrataPassword)
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

        .PARAMETER SocrataUsername
            Socrata username or API key identifier.

        .PARAMETER SocrataPassword
            Socrata password or API key secret.

        .OUTPUTS
            PSObject
    #>
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([PSObject])]
    Param(
        [Parameter(Mandatory = $true)][String]$Domain,
        [Parameter(Mandatory = $true)][String]$Name,
        [Parameter(Mandatory = $false)][String]$SocrataUsername = $null,
        [Parameter(Mandatory = $false)][SecureString]$SocrataPassword = $null
    )
    Process {
        # Get credentials
        $Credentials = Get-SocrataCredentials `
            -SocrataUsername $SocrataUsername `
            -SocrataPassword $SocrataPassword `
            -ErrorAction "Stop"
        $AuthString = Convert-SocrataCredentialsToAuthString `
            -Credentials $Credentials `
            -ErrorAction "Stop"

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

        .PARAMETER SocrataUsername
            Socrata username or API key identifier.

        .PARAMETER SocrataPassword
            Socrata password or API key secret.

        .OUTPUTS
            PSObject
    #>
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([PSObject])]
    Param(
        [Parameter(Mandatory = $true)][String]$Domain,
        [Parameter(Mandatory = $true)][ValidatePattern("^\w{4}-\w{4}$")][String]$DatasetId,
        [Parameter(Mandatory = $true)][ValidateSet("update", "replace")][String]$Type,
        [Parameter(Mandatory = $false)][String]$SocrataUsername = $null,
        [Parameter(Mandatory = $false)][SecureString]$SocrataPassword = $null
    )
    Process {
        # Get credentials
        $Credentials = Get-SocrataCredentials `
            -SocrataUsername $SocrataUsername `
            -SocrataPassword $SocrataPassword `
            -ErrorAction "Stop"
        $AuthString = Convert-SocrataCredentialsToAuthString `
            -Credentials $Credentials `
            -ErrorAction "Stop"

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

        .PARAMETER SocrataUsername
            Socrata username or API key identifier.

        .PARAMETER SocrataPassword
            Socrata password or API key secret.

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
        [Parameter(Mandatory = $false)][String]$SocrataUsername = $null,
        [Parameter(Mandatory = $false)][SecureString]$SocrataPassword = $null
    )
    Process {
        # Get credentials
        $Credentials = Get-SocrataCredentials `
            -SocrataUsername $SocrataUsername `
            -SocrataPassword $SocrataPassword `
            -ErrorAction "Stop"
        $AuthString = Convert-SocrataCredentialsToAuthString `
            -Credentials $Credentials `
            -ErrorAction "Stop"

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

        .PARAMETER SocrataUsername
            Socrata username or API key identifier.

        .PARAMETER SocrataPassword
            Socrata password or API key secret.

        .OUTPUTS
            PSObject
    #>
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([PSObject])]
    Param(
        [Parameter(Mandatory = $true)][String]$Domain,
        [Parameter(Mandatory = $true)][ValidatePattern("^\w{4}-\w{4}$")][String]$DatasetId,
        [Parameter(Mandatory = $true)][Int64]$RevisionId,
        [Parameter(Mandatory = $false)][String]$SocrataUsername = $null,
        [Parameter(Mandatory = $false)][SecureString]$SocrataPassword = $null
    )
    Process {
        # Get credentials
        $Credentials = Get-SocrataCredentials `
            -SocrataUsername $SocrataUsername `
            -SocrataPassword $SocrataPassword `
            -ErrorAction "Stop"
        $AuthString = Convert-SocrataCredentialsToAuthString `
            -Credentials $Credentials `
            -ErrorAction "Stop"

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
            "kmz", or "geojson").

        .PARAMETER SocrataUsername
            Socrata username or API key identifier.

        .PARAMETER SocrataPassword
            Socrata password or API key secret.

        .OUTPUTS
            PSObject
    #>
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([PSObject])]
    Param(
        [Parameter(Mandatory = $true)][String]$Domain,
        [Parameter(Mandatory = $true)][Int64]$SourceId,
        [Parameter(Mandatory = $true)][String]$Filepath,
        [Parameter(Mandatory = $false)][ValidateSet("csv", "tsv", "xls", "xlsx", "shapefile", "kml", "kmz", "geojson")][String]$Filetype = $null,
        [Parameter(Mandatory = $false)][Int64]$TimeoutSec = 60 * 60 * 24, # Default: 24 hours
        [Parameter(Mandatory = $false)][String]$SocrataUsername = $null,
        [Parameter(Mandatory = $false)][SecureString]$SocrataPassword = $null
    )
    Process {
        # Get credentials
        $Credentials = Get-SocrataCredentials `
            -SocrataUsername $SocrataUsername `
            -SocrataPassword $SocrataPassword `
            -ErrorAction "Stop"
        $AuthString = Convert-SocrataCredentialsToAuthString `
            -Credentials $Credentials `
            -ErrorAction "Stop"

        # Determine request Content-Type
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
            Write-Host "No filetype specified; attempting to infer content type from extension"
            $FileExtension = [System.IO.Path]::GetExtension($Filepath).ToLower().Substring(1)
            $ContentType = $ContentTypeMappings.$FileExtension
            Write-Host "Inferred content type '$ContentType' from extension '$FileExtension'"
        }
        else {
            $ContentType = $ContentTypeMappings.$Filetype
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

        .PARAMETER SocrataUsername
            Socrata username or API key identifier.

        .PARAMETER SocrataPassword
            Socrata password or API key secret.

        .OUTPUTS
            Boolean
    #>
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([Boolean])]
    Param(
        [Parameter(Mandatory = $true)][String]$Domain,
        [Parameter(Mandatory = $true)][Int64]$SourceId,
        [Parameter(Mandatory = $true)][Int64]$InputSchemaId,
        [Parameter(Mandatory = $false)][String]$SocrataUsername = $null,
        [Parameter(Mandatory = $false)][SecureString]$SocrataPassword = $null
    )
    Process {
        # Get credentials
        $Credentials = Get-SocrataCredentials `
            -SocrataUsername $SocrataUsername `
            -SocrataPassword $SocrataPassword `
            -ErrorAction "Stop"
        $AuthString = Convert-SocrataCredentialsToAuthString `
            -Credentials $Credentials `
            -ErrorAction "Stop"

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

        .PARAMETER SocrataUsername
            Socrata username or API key identifier.

        .PARAMETER SocrataPassword
            Socrata password or API key secret.

        .OUTPUTS
            PSObject
    #>
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([PSObject])]
    Param(
        [Parameter(Mandatory = $true)][String]$Domain,
        [Parameter(Mandatory = $true)][ValidatePattern("^\w{4}-\w{4}$")][String]$DatasetId,
        [Parameter(Mandatory = $true)][Int64]$RevisionId,
        [Parameter(Mandatory = $false)][String]$SocrataUsername = $null,
        [Parameter(Mandatory = $false)][SecureString]$SocrataPassword = $null
    )
    Process {
        # Get credentials
        $Credentials = Get-SocrataCredentials `
            -SocrataUsername $SocrataUsername `
            -SocrataPassword $SocrataPassword `
            -ErrorAction "Stop"
        $AuthString = Convert-SocrataCredentialsToAuthString `
            -Credentials $Credentials `
            -ErrorAction "Stop"

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
            Write-Debug "Attempt $Attempts of $MaxAttempts"
            try {
                $Result = $Action.Invoke()
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

        $Result
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

        .PARAMETER Publish
            Whether to publish the dataset or leave it as an unpublished revision.

        .PARAMETER SocrataUsername
            Socrata username or API key identifier.

        .PARAMETER SocrataPassword
            Socrata password or API key secret.

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
        [Parameter(Mandatory = $false)][String]$SocrataUsername = $null,
        [Parameter(Mandatory = $false)][SecureString]$SocrataPassword = $null
    )
    Process {
        # Get credentials
        $Credentials = Get-SocrataCredentials `
            -SocrataUsername $SocrataUsername `
            -SocrataPassword $SocrataPassword `
            -ErrorAction "Stop"

        # Create revision
        [PSObject]$Revision = New-Revision `
            -Domain $Domain `
            -Name $Name `
            -SocrataUsername $Credentials.UserName `
            -SocrataPassword $Credentials.Password `
            -ErrorAction "Stop"
        [String]$DatasetId = $Revision.resource.fourfour
        [Int64]$RevisionId = $Revision.resource.revision_seq
        [String]$RevisionUrl = "https://$Domain/d/$DatasetId/revisions/$RevisionId"

        # Set audience on revision
        [PSObject]$Revision = Set-Audience `
            -Domain $Domain `
            -DatasetId $DatasetId `
            -Audience $Audience `
            -SocrataUsername $Credentials.UserName `
            -SocrataPassword $Credentials.Password `
            -ErrorAction "Stop"

        # Create source on revision
        [PSObject]$Source = Add-Source `
            -Domain $Domain `
            -DatasetId $DatasetId `
            -RevisionId $RevisionId `
            -SocrataUsername $Credentials.UserName `
            -SocrataPassword $Credentials.Password `
            -ErrorAction "Stop"
        [Int64]$SourceId = $Source.resource.id

        # Upload file to source
        if (-not $Filetype) {
            [PSObject]$Upload = Add-Upload `
                -Domain $Domain `
                -SourceId $SourceId `
                -Filepath $Filepath `
                -SocrataUsername $Credentials.UserName `
                -SocrataPassword $Credentials.Password `
                -ErrorAction "Stop"
        }
        else {
            [PSObject]$Upload = Add-Upload `
                -Domain $Domain `
                -SourceId $SourceId `
                -Filepath $Filepath `
                -Filetype $Filetype `
                -SocrataUsername $Credentials.UserName `
                -SocrataPassword $Credentials.Password `
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
        [Boolean]$SchemaSucceeded = Wait-ForSuccess `
            -Action { Assert-SchemaSucceeded `
                -Domain $Domain `
                -SourceId $SourceId `
                -InputSchemaId $LatestInputSchemaId `
                -SocrataUsername $Credentials.UserName `
                -SocrataPassword $Credentials.Password `
                -ErrorAction "Stop" } `
            -ErrorAction "Stop"

        # Publish revision
        if ($Publish -eq $true) {
            [PSObject]$PublishedRevision = Publish-Revision `
                -Domain $Domain `
                -DatasetId $DatasetId `
                -RevisionId $RevisionId `
                -SocrataUsername $Credentials.UserName `
                -SocrataPassword $Credentials.Password
        }

        Write-Host "View revision: $RevisionUrl"
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
            "kmz", or "geojson").

        .PARAMETER Publish
            Whether to publish the dataset or leave it as an unpublished revision.

        .PARAMETER SocrataUsername
            Socrata username or API key identifier.

        .PARAMETER SocrataPassword
            Socrata password or API key secret.

        .OUTPUTS
            String
    #>
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([String])]
    Param(
        [Parameter(Mandatory = $true)][String]$Domain,
        [Parameter(Mandatory = $true)][ValidatePattern("^\w{4}-\w{4}$")][String]$DatasetId,
        [Parameter(Mandatory = $true)][ValidateSet("update", "replace")][String]$Type,
        [Parameter(Mandatory = $true)][ValidateScript({ Test-Path $_ })][String]$Filepath,
        [Parameter(Mandatory = $false)][ValidateSet("csv", "tsv", "xls", "xlsx", "shapefile", "kml", "kmz", "geojson")][String]$Filetype = $null,
        [Parameter(Mandatory = $false)][Boolean]$Publish = $true,
        [Parameter(Mandatory = $false)][String]$SocrataUsername = $null,
        [Parameter(Mandatory = $false)][SecureString]$SocrataPassword = $null
    )
    Process {
        # Get credentials
        $Credentials = Get-SocrataCredentials `
            -SocrataUsername $SocrataUsername `
            -SocrataPassword $SocrataPassword `
            -ErrorAction "Stop"

        # Create revision
        [PSObject]$Revision = Open-Revision `
            -Domain $Domain `
            -DatasetId $DatasetId `
            -Type $Type `
            -SocrataUsername $Credentials.UserName `
            -SocrataPassword $Credentials.Password `
            -ErrorAction "Stop"
        [Int64]$RevisionId = $Revision.resource.revision_seq
        [String]$RevisionUrl = "https://$Domain/d/$DatasetId/revisions/$RevisionId"

        # Create source on revision
        [PSObject]$Source = Add-Source `
            -Domain $Domain `
            -DatasetId $DatasetId `
            -RevisionId $RevisionId `
            -SocrataUsername $Credentials.UserName `
            -SocrataPassword $Credentials.Password `
            -ErrorAction "Stop"
        [Int64]$SourceId = $Source.resource.id

        # Upload file to source
        if (-not $Filetype) {
            [PSObject]$Upload = Add-Upload `
                -Domain $Domain `
                -SourceId $SourceId `
                -Filepath $Filepath `
                -SocrataUsername $Credentials.UserName `
                -SocrataPassword $Credentials.Password `
                -ErrorAction "Stop"
        }
        else {
            [PSObject]$Upload = Add-Upload `
                -Domain $Domain `
                -SourceId $SourceId `
                -Filepath $Filepath `
                -Filetype $Filetype `
                -SocrataUsername $Credentials.UserName `
                -SocrataPassword $Credentials.Password `
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
        [Boolean]$SchemaSucceeded = Wait-ForSuccess `
            -Action { Assert-SchemaSucceeded `
                -Domain $Domain `
                -SourceId $SourceId `
                -InputSchemaId $LatestInputSchemaId `
                -SocrataUsername $Credentials.UserName `
                -SocrataPassword $Credentials.Password `
                -ErrorAction "Stop" } `
            -ErrorAction "Stop"

        # Publish revision
        if ($Publish -eq $true) {
            [PSObject]$PublishedRevision = Publish-Revision `
                -Domain $Domain `
                -DatasetId $DatasetId `
                -RevisionId $RevisionId `
                -SocrataUsername $Credentials.UserName `
                -SocrataPassword $Credentials.Password
        }

        Write-Host "View revision: $RevisionUrl"
        $RevisionUrl
    }
}
