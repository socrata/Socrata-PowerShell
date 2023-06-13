#Requires -Version 6

BeforeAll {
    Import-Module "$PSScriptRoot/Socrata.psm1"

    # Set constants
    $TestDomain = $Env:SOCRATA_POWERSHELL_TEST_DOMAIN
    $TestDatasetId = $Env:SOCRATA_POWERSHELL_TEST_DATASET_ID
    $CsvFilePath = "$PSScriptRoot/Test-Data/iris_sample.csv"
    $RevisionUrlPattern = "/d/(?<dataset_id>\w{4}-\w{4})/revisions/(?<revision_id>\d+)$"

    function Get-SocrataTestingCredentials {
        New-Object PSCredential(
            $Env:SOCRATA_USERNAME,
            (ConvertTo-SecureString -String $Env:SOCRATA_PASSWORD -AsPlainText -Force)
        )
    }

    $Credentials = Get-SocrataTestingCredentials

    function Get-RevisionJson ([String]$RevisionUrl, [String]$DatasetId) {
        # Extract revision ID from frontend URL
        $RevisionUrl -Match $RevisionUrlPattern
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
}

Describe "Get-SocrataCredentials" {
    It "Given no explicitly passed credentials, obtains Socrata credentials from the environment" {
        $Credentials = Get-SocrataCredentials
        $Credentials.UserName | Should -BeExactly $Env:SOCRATA_USERNAME
    }

    It "Given explicitly passed credentials, returns those same credentials" {
        $TestCredentials = New-Object PSCredential(
            "some_username",
            (ConvertTo-SecureString -String "password" -AsPlainText -Force)
        )
        $Credentials = Get-SocrataCredentials -Credentials $TestCredentials
        $Credentials.UserName | Should -BeExactly $TestCredentials.UserName
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
        Start-Sleep -Seconds 30
        $RevisionUrl | Should -Match $RevisionUrlPattern
        $RevisionUrl -Match $RevisionUrlPattern
        $NewDatasetId = $Matches.dataset_id
        $RevisionJson = Get-RevisionJson -RevisionUrl $RevisionUrl -DatasetId $NewDatasetId

        # Check that the update was successful
        $RevisionJson.resource.closed_at | Should -Not -BeNullOrEmpty
        $RevisionJson.resource.permissions.scope | Should -BeExactly "site"

        # Delete newly created dataset
        Remove-Dataset -DatasetId $NewDatasetId
    }
}


Describe "Update-Dataset" {
    It "Given a Socrata domain, dataset ID, and CSV file, updates an existing dataset" {
        $RevisionType = "update"

        # Execute function
        $RevisionUrl = Update-Dataset `
            -Domain $TestDomain `
            -DatasetId $TestDatasetId `
            -Filepath $CsvFilepath `
            -Type $RevisionType `
            -Publish $true `
            -Credentials $Credentials

        # Wait for the revision to finish applying, then check that it completed successfully
        Start-Sleep -Seconds 30
        $RevisionUrl | Should -Match $RevisionUrlPattern
        $RevisionJson = Get-RevisionJson -RevisionUrl $RevisionUrl -DatasetId $TestDatasetId

        # Check that the revision was successful
        $RevisionJson.resource.action.type | Should -BeExactly $RevisionType
        $RevisionJson.resource.closed_at | Should -Not -BeNullOrEmpty
    }

    It "Given a Socrata domain, dataset ID, and CSV file, deletes rows in an existing dataset" {
        $RevisionType = "delete"

        # Execute function
        $RevisionUrl = Update-Dataset `
            -Domain $TestDomain `
            -DatasetId $TestDatasetId `
            -Filepath $CsvFilepath `
            -Type $RevisionType `
            -Publish $true `
            -Credentials $Credentials

        # Wait for the revision to finish applying, then check that it completed successfully
        Start-Sleep -Seconds 30
        $RevisionUrl | Should -Match $RevisionUrlPattern
        $RevisionJson = Get-RevisionJson -RevisionUrl $RevisionUrl -DatasetId $TestDatasetId

        # Check that the revision was successful
        $RevisionJson.resource.action.type | Should -BeExactly $RevisionType
        $RevisionJson.resource.closed_at | Should -Not -BeNullOrEmpty
    }

    It "Given a Socrata domain, dataset ID, and CSV file, replaces an existing dataset" {
        $RevisionType = "replace"

        # Execute function
        $RevisionUrl = Update-Dataset `
            -Domain $TestDomain `
            -DatasetId $TestDatasetId `
            -Filepath $CsvFilepath `
            -Type $RevisionType `
            -Publish $true `
            -Credentials $Credentials

        # Wait for the revision to finish applying, then check that it completed successfully
        Start-Sleep -Seconds 30
        $RevisionUrl | Should -Match $RevisionUrlPattern
        $RevisionJson = Get-RevisionJson -RevisionUrl $RevisionUrl -DatasetId $TestDatasetId

        # Check that the revision was successful
        $RevisionJson.resource.action.type | Should -BeExactly $RevisionType
        $RevisionJson.resource.closed_at | Should -Not -BeNullOrEmpty
    }
}
