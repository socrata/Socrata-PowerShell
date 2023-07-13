#Requires -Version 6

BeforeAll {
    Import-Module "$PSScriptRoot/Socrata.psm1"

    # Set constants
    $TestDomain = $Env:SOCRATA_POWERSHELL_TEST_DOMAIN
    $TestDatasetId = $Env:SOCRATA_POWERSHELL_TEST_DATASET_ID
    $RevisionUrlPattern = "/d/(?<dataset_id>\w{4}-\w{4})/revisions/(?<revision_id>\d+)$"

    function Get-SocrataTestingCredentials {
        New-Object PSCredential(
            $Env:SOCRATA_USERNAME,
            (ConvertTo-SecureString -String $Env:SOCRATA_PASSWORD -AsPlainText -Force)
        )
    }

    $Credentials = Get-SocrataTestingCredentials

    function Write-TemporaryCsvFile() {
        $CsvData = (
            "row_id,sepal_length,sepal_width,petal_length,petal_width,species`n" +
            "1,5.7,2.9,4.2,1.3,versicolor"
        )

        # Create temporary file
        $TemporaryCsvFile = New-TemporaryFile
        $TemporaryDir = $TemporaryCsvFile.Directory

        # Rename file to use .csv extension
        $TemporaryCsvFilepath = Join-Path $TemporaryDir.FullName "$($TemporaryCsvFile.Name).csv"
        $TemporaryCsvFile.MoveTo($TemporaryCsvFilepath)

        # Write CSV data to file
        $CsvData | Out-File -FilePath $TemporaryCsvFilepath

        $TemporaryCsvFilepath
    }

    $CsvFilepath = Write-TemporaryCsvFile

    function Get-RevisionJson ([String]$RevisionUrl) {
        # Extract revision ID from frontend URL
        $RevisionUrl -Match $RevisionUrlPattern
        $DatasetId = $Matches.dataset_id
        $RevisionId = $Matches.revision_id
        $RevisionApiUrl = "https://$TestDomain/api/publishing/v1/revision/$DatasetId/$RevisionId"

        # Get revision JSON
        $RevisionJson = Invoke-RestMethod `
            -Method "Get" `
            -Uri $RevisionApiUrl `
            -Authentication "Basic" `
            -Credential $Credentials
        $RevisionJson
    }

    function Remove-Dataset ([String]$DatasetId) {
        $DeleteUrl = "https://$TestDomain/api/views/$DatasetId"
        $DeleteJson = Invoke-RestMethod `
            -Method "Delete" `
            -Uri $DeleteUrl `
            -Authentication "Basic" `
            -Credential $Credentials
        $DeleteJson
    }

    function Confirm-RevisionSucceeded ([String]$RevisionUrl) {
        $MaxAttempts = 20
        $Interval = 3

        $Attempt = 1
        do {
            $RevisionJson = Get-RevisionJson -RevisionUrl $RevisionUrl
            Start-Sleep -Seconds $Interval
            $Attempt += 1
        } until ($RevisionJson.resource.closed_at -ne $null -or $Attempt -gt $MaxAttempts)

        if ($Attempt -gt $MaxAttempts) {
            throw "Exceeded maximum $MaxAttempts attempts when confirming revision succeeded: $RevisionUrl"
        }

        $RevisionJson
    }
}

Describe "Socrata-PowerShell" {
    It "Does not trigger PSScriptAnalyzer warnings or errors" {
        Import-Module "PSScriptAnalyzer"
        $ScriptAnalysisOutput = @(
            Invoke-ScriptAnalyzer `
                -Path "$PSScriptRoot/Socrata.psm1" `
                -Severity @( "Warning", "Error" ) `
                -CustomRulePath $PSScriptRoot `
                -IncludeDefaultRules
        )
        $ScriptAnalysisOutput.Length | Should -BeExactly 0
    }

    It "Exports only commands that are part of its public API" {
        $ExpectedCommands = @(
            "New-Dataset",
            "Update-Dataset",
            "Get-Metadata",
            "Update-Metadata"
        ) | Sort-Object
        $Commands = (Get-Command -Module "Socrata").Name | Sort-Object
        $Commands | Should -Be $ExpectedCommands
    }
}

Describe "SocrataClient" {
    It "Given no explicitly passed credentials, obtains Socrata credentials from the environment" {
        & (Get-Module "Socrata") {
            $Client = New-Object SocrataClient -ArgumentList "example.domain.com"
            $Client.Auth.UserName | Should -BeExactly $Env:SOCRATA_USERNAME
        }
    }

    It "Given explicitly passed credentials, returns those same credentials" {
        & (Get-Module "Socrata") {
            $Auth = New-Object PSCredential(
                "example_username",
                (ConvertTo-SecureString -String "example_password" -AsPlainText -Force)
            )
            $Client = New-Object SocrataClient -ArgumentList "example.domain.com", $Auth
            $Client.Auth.UserName | Should -BeExactly $Auth.UserName
        }
    }
}

Describe "New-Dataset" {
    It "Given a Socrata domain and CSV file, creates a new dataset" {
        # Execute function
        $RevisionUrl = New-Dataset `
            -Domain $TestDomain `
            -Name "Testing Socrata-PowerShell" `
            -Filepath $CsvFilepath `
            -Audience "site" `
            -Publish $true `
            -Credentials $Credentials

        # Wait for the revision to finish applying, then check that it completed successfully
        $RevisionUrl | Should -Match $RevisionUrlPattern
        $RevisionUrl -Match $RevisionUrlPattern
        $NewDatasetId = $Matches.dataset_id
        $RevisionJson = Confirm-RevisionSucceeded -RevisionUrl $RevisionUrl

        # Check that the update was successful
        $RevisionJson.resource.permissions.scope | Should -BeExactly "site"

        # Delete newly created dataset
        Remove-Dataset -DatasetId $NewDatasetId
    }
}

Describe "Update-Dataset" {
    It "Given a Socrata domain, dataset ID, and CSV file, performs an update of type '<_>'" -ForEach "update", "delete", "replace" {
        $RevisionType = $_

        # Execute function
        $RevisionUrl = Update-Dataset `
            -Domain $TestDomain `
            -DatasetId $TestDatasetId `
            -Filepath $CsvFilepath `
            -Type $RevisionType `
            -Publish $true `
            -Credentials $Credentials

        # Wait for the revision to finish applying, then check that it completed successfully
        $RevisionUrl | Should -Match $RevisionUrlPattern
        $RevisionJson = Confirm-RevisionSucceeded -RevisionUrl $RevisionUrl

        # Check that the revision was successful
        $RevisionJson.resource.action.type | Should -BeExactly $RevisionType
    }
}

Describe "Get-Metadata" {
    It "Given a Socrata domain and asset ID, gets the asset's metadata" {
        # Execute function
        $MetadataJson = Get-Metadata `
            -Domain $TestDomain `
            -DatasetId $TestDatasetId `
            -Credentials $Credentials

        # Check that the metadata update was successful
        $MetadataJson.name | Should -Not -BeNullOrEmpty
        $MetadataJson.customFields.TestFieldset.TestField | Should -Not -BeNullOrEmpty
    }
}

Describe "Update-Metadata" {
    It "Given a Socrata domain and asset ID, and a metadata object, updates the asset's metadata" {
        $RandomGuid = (New-Guid).ToString()
        $Fields = @{
            "customFields" = @{
                "TestFieldset" = @{
                    "TestField" = $RandomGuid
                }
            }
        }

        # Execute function
        $MetadataJson = Update-Metadata `
            -Domain $TestDomain `
            -DatasetId $TestDatasetId `
            -Fields $Fields `
            -Credentials $Credentials

        # Check that the metadata update was successful
        $MetadataJson.metadata.customFields.TestFieldset.TestField | Should -BeExactly $RandomGuid
    }
}

AfterAll {
    Remove-Item $CsvFilepath
}
