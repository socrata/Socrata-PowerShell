Socrata-PowerShell
==================

A PowerShell module for creating and updating datasets on a Socrata domain.

## Contents

* [Installation](#installation)
* [Quickstart](#quickstart)
* [Authentication](#authentication)
* [Examples](#examples)
  + [Update an existing dataset](#update-an-existing-dataset)
  + [Create a new dataset](#create-a-new-dataset)
  + [Create a dataset draft](#create-a-dataset-draft)
  + [Get dataset metadata](#get-dataset-metadata)
  + [Update dataset metadata](#update-dataset-metadata)
* [Tests](#tests)

## Installation

To install this module:

1. Download this repository [as a ZIP] or `git clone` it locally
2. Unzip the repository, if necessary
3. Move the `Socrata-PowerShell` directory to wherever you'd like to keep it
4. [Import the module] in your PowerShell scripts like so: `Import-Module -Name "./Socrata-PowerShell/Socrata.psm1"`

Be sure to edit the `-Name` parameter value so it points to the correct path for the `Socrata.psm1` file in your environment.

For detailed information on installing PowerShell modules locally and globally, see [Installing a PowerShell Module].

[as a ZIP]: https://github.com/socrata/Socrata-PowerShell/archive/refs/heads/main.zip
[Import the module]: https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/import-module
[Installing a PowerShell Module]: https://docs.microsoft.com/en-us/powershell/scripting/developer/module/installing-a-powershell-module

## Quickstart

Here's a simple PowerShell script that performs a full replace on an existing dataset from a CSV file:

```powershell
Import-Module -Name "./Socrata-PowerShell/Socrata.psm1" -Function "Update-Dataset"

$RevisionUrl = Update-Dataset `
    -Domain "data.example.gov" `
    -DatasetId "fej7-9vb3" `
    -Type "replace" `
    -Publish $true `
    -Filepath "\\treasurer\financial_data\budget.csv" `
    -ErrorAction "Stop"

Write-Host "Update complete! See dataset revision here: $RevisionUrl"
```

## Authentication

To use this library, you must have access to a Socrata user account with permissions to create and/or update datasets on a Socrata domain.

While Socrata APIs will accept a username and password as HTTP Basic Auth credentials, it's best to [generate a pair of API keys] and use those instead.

By default, this package will automatically look for Socrata credentials under the environment variables `SOCRATA_USERNAME` and `SOCRATA_PASSWORD`. However, you can also supply them explicitly via a `PSCredential`:

```powershell
Import-Module -Name "./Socrata-PowerShell/Socrata.psm1" -Function "Update-Dataset"

$Credentials = New-Object PSCredential(
    $Env:SOCRATA_KEY_ID,
    ($Env:SOCRATA_KEY_SECRET | ConvertTo-SecureString -AsPlainText -Force)
)

Update-Dataset `
    -Domain "data.example.gov" `
    -DatasetId "fej7-9vb3" `
    -Type "replace" `
    -Filepath "\\treasurer\financial_data\budget.csv" `
    -Credentials $Credentials
```

As a reminder, do not store secure credentials in a script or commit them to version control.

[generate a pair of API keys]: https://support.socrata.com/hc/en-us/articles/360015776014-API-Keys

## Examples

### Update an existing dataset

```powershell
Import-Module -Name "./Socrata-PowerShell/Socrata.psm1" -Function "Update-Dataset"

$Credentials = New-Object PSCredential(
    $Env:SOCRATA_KEY_ID,
    ($Env:SOCRATA_KEY_SECRET | ConvertTo-SecureString -AsPlainText -Force)
)

$Url = Update-Dataset `
    -Domain "data.example.gov" `                   # Required
    -DatasetId "c2xb-y8f6" `                       # Required
    -Type "update" `                               # Required; "update" (upsert/append), "replace" (full replace), or "delete" (delete rows)
    -Filepath "C:\Documents\vet_facils.geojson" `  # Required
    -Filetype "geojson" `                          # Optional; if not supplied, this is guessed from the filepath
    -Publish $true `                               # Optional; $true or $false (default: $true)
    -Credentials $Credentials                      # Optional; if not supplied, this is looked up from the env variables SOCRATA_USERNAME and SOCRATA_PASSWORD
```

### Create a new dataset

Note: it's not unusual to run into schema errors and data quality issues when creating a dataset programmatically. A good workaround is to create a new dataset using the [Data Management Experience] user interface, add any desired fixes or schema changes, then publish. After that, you can schedule programmatic [updates] for the dataset going forward.

[Data Management Experience]: https://support.socrata.com/hc/en-us/articles/115016067067-Using-the-Socrata-Data-Management-Experience
[updates]: #update-an-existing-dataset

```powershell
Import-Module -Name "./Socrata-PowerShell/Socrata.psm1" -Function "New-Dataset"

$Credentials = New-Object PSCredential(
    $Env:SOCRATA_KEY_ID,
    ($Env:SOCRATA_KEY_SECRET | ConvertTo-SecureString -AsPlainText -Force)
)

$Url = New-Dataset `
    -Domain "data.example.gov" `                   # Required
    -Name "Hospital Bed Availability by County" `  # Required
    -Filepath "\\datasets\BEDS_AVAIL.xlsx" `       # Required
    -Filetype "xlsx" `                             # Optional; if not supplied, this is guessed from the filepath
    -Audience "private" `                          # Optional; "private" or "public" (default: "private")
    -Publish $true `                               # Optional; $true or $false (default: $true)
    -Credentials $Credentials                      # Optional; if not supplied, this is looked up from the env variables SOCRATA_USERNAME and SOCRATA_PASSWORD
```

### Create a dataset draft

It is often desired to create a draft revision of a new or existing dataset without publishing the draft. For example, you may want to manually inspect a dataset in the [Data Management Experience] user interface before publishing.

The functions `Update-Dataset` and `New-Dataset` both accept a `-Publish` parameter that, when set to `$false`, will leave the revision in draft (unpublished) state.

```powershell
Import-Module -Name "./Socrata-PowerShell/Socrata.psm1" -Function "New-Dataset"

$Url = New-Dataset `
    -Domain "data.example.gov" `                   # Required
    -Name "Assisted Living Facilities by State" `  # Required
    -Filepath "datasets\assisted_living.csv" `     # Required
    -Publish $false                                # Optional; $true or $false (default: $true)
```

[Data Management Experience]: https://support.socrata.com/hc/en-us/articles/115016067067-Using-the-Socrata-Data-Management-Experience

### Get dataset metadata

```powershell
Import-Module -Name "./Socrata-PowerShell/Socrata.psm1" -Function "Get-Metadata"

$Credentials = New-Object PSCredential(
    $Env:SOCRATA_KEY_ID,
    ($Env:SOCRATA_KEY_SECRET | ConvertTo-SecureString -AsPlainText -Force)
)

$Fields = Get-Metadata `
    -Domain "data.example.gov" `                   # Required
    -DatasetId "prx6-94ku" `                       # Required
    -Credentials $Credentials                      # Optional; if not supplied, this is looked up from the env variables SOCRATA_USERNAME and SOCRATA_PASSWORD
```

This will return a hashtable like the following:

```powershell
@{
    id              = "prx6-94ku"
    name            = "Gross Domestic Product by County, 2021"
    attribution     = "Bureau of Economic Analysis (BEA)"
    # ...
    customFields    = @{
        Department  = @{
            Name    = "Economic Development"
            Office  = "Office of Data and Performance"
        }
    }
    tags            = @( "economic", "performance", "gdp", "counties" )
}
```

### Update dataset metadata

```powershell
Import-Module -Name "./Socrata-PowerShell/Socrata.psm1" -Function "Update-Metadata"

$Credentials = New-Object PSCredential(
    $Env:SOCRATA_KEY_ID,
    ($Env:SOCRATA_KEY_SECRET | ConvertTo-SecureString -AsPlainText -Force)
)

$Fields = @{
    description    = "An estimate of the value of goods and services by county."
    category       = "Economy"
    customFields   = @{
        Department = @{
            Team   = "Innovation and Analytics Team"
        }
    }
}

$Result = Update-Metadata `
    -Domain "data.example.gov" `                   # Required
    -DatasetId "prx6-94ku" `                       # Required
    -Fields $Fields `                              # Required; must be a hashtable containing metadata fields as key-value pairs
    -ValidateOnly $false `                         # Optional; $true or $false (default: $false)
    -Strict $false `                               # Optional; $true or $false (default: $false)
    -Credentials $Credentials                      # Optional; if not supplied, this is looked up from the env variables SOCRATA_USERNAME and SOCRATA_PASSWORD
```

## Tests

To run Socrata-PowerShell's integration tests, run [Pester] at the repository root:

```powershell
Invoke-Pester -Output "Detailed"
```

For the tests to pass, the following environment variables must be set:

* `SOCRATA_POWERSHELL_TEST_DOMAIN`
* `SOCRATA_POWERSHELL_TEST_DATASET_ID`
* `SOCRATA_USERNAME`
* `SOCRATA_PASSWORD`

Script analysis is included in the test suite. To run script analysis separately, use [PSScriptAnalyzer]:

```powershell
Invoke-ScriptAnalyzer -Path "./Socrata.psm1"
```

[Pester]: https://pester.dev
[PSScriptAnalyzer]: https://learn.microsoft.com/en-us/powershell/module/psscriptanalyzer/?view=ps-modules
