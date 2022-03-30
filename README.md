Socrata-PowerShell
==================

A PowerShell module for creating and updating datasets on a Socrata domain via the [Dataset Management API].

[Dataset Management API]: https://dev.socrata.com/publishers/dsmapi.html

## Installation

To install this module:

1. Download this repository as a ZIP, or clone it locally using `git clone`
2. Unzip the repository, if necessary
3. Move the `Socrata-PowerShell` directory to wherever you'd like to keep it
4. [Import the module] in your PowerShell scripts like so: `Import-Module -Name "./Socrata-PowerShell/Socrata"`

Be sure to edit the `-Name` parameter value so it points to the correct path for the `Socrata.psm1` file in your environment.

For detailed information on installing PowerShell modules locally and globally, see [Installing a PowerShell Module].

[Import the module]: https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/import-module
[Installing a PowerShell Module]: https://docs.microsoft.com/en-us/powershell/scripting/developer/module/installing-a-powershell-module

## Quickstart

Here's a simple PowerShell script that performs a full replace on an existing dataset from a CSV file:

```powershell
Import-Module -Name "./Socrata-PowerShell/Socrata" -Function "Update-Dataset"

Write-Host "Updating dataset..."

Update-Dataset `
    -Domain "data.example.gov" `
    -DatasetId "fej7-9vb3" `
    -Type "replace" `
    -Filepath "\\treasurer\financial_data\budget.csv" `
    -ErrorAction "Stop"

Write-Host "Update complete!"
```

## Authentication

To use this library, you must have access to a Socrata user account with permissions to create and/or update datasets on your domain.

While the `New-Dataset` and `Update-Dataset` functions will accept a Socrata username and password, it's best to [generate a pair of API keys] and use those instead.

By default, this library will automatically look for Socrata credentials under the environment variables `SOCRATA_USERNAME` and `SOCRATA_PASSWORD`. However, you can also supply them explicitly:

```powershell
Update-Dataset `
    -Domain "data.example.gov" `
    -DatasetId "fej7-9vb3" `
    -Type "replace" `
    -Filepath "\\treasurer\financial_data\budget.csv" `
    -SocrataUsername $Env:API_KEY_ID `
    -SocrataPassword $Env:API_KEY_SECRET
```

Reminder: do not store your secure credentials in a script or commit them to version control.

[generate a pair of API keys]: https://support.socrata.com/hc/en-us/articles/360015776014-API-Keys

## Examples

### Update an existing dataset

```powershell
Import-Module -Name "./Socrata-PowerShell/Socrata" -Function "Update-Dataset"

$Url = Update-Dataset `
    -Domain "data.example.gov" `                   # Required
    -DatasetId "c2xb-y8f6" `                       # Required
    -Type "update" `                               # Required; "update" (upsert/append) or "replace" (full replace)
    -Filepath "C:\Documents\vet_facils.geojson" `  # Required
    -Filetype "geojson" `                          # Optional; if not supplied, this is guessed from the filepath
    -Publish $true `                               # Optional; $true or $false (default: $true)
    -SocrataUsername $Env:API_KEY_ID `             # Optional; if not supplied, this is looked up from the env variable SOCRATA_USERNAME
    -SocrataPassword $Env:API_KEY_SECRET           # Optional; if not supplied, this is looked up from the env variable SOCRATA_PASSWORD
```

### Create a new dataset

Warning: when creating a new dataset programmatically, it's very common to run into data quality errors and schema issues. As a result, it's usually better to create a new dataset using the [Data Management Experience] user interface, implement any desired schema changes, metadata additions, etc., and then publish. You can then schedule programmatic [updates] for the dataset going forward.

```powershell
Import-Module -Name "./Socrata-PowerShell/Socrata" -Function "New-Dataset"

$Url = New-Dataset `
    -Domain "data.example.gov" `                   # Required
    -Name "Hospital Bed Availability by County" `  # Required
    -Filepath "\\datasets\BEDS_AVAIL.xlsx" `       # Required
    -Filetype "xlsx" `                             # Optional; if not supplied, this is guessed from the filepath
    -Audience "private" `                          # Optional; "private" or "public" (default: "private")
    -Publish $true `                               # Optional; $true or $false (default: $true)
    -SocrataUsername $Env:API_KEY_ID `             # Optional; if not supplied, this is looked up from the env variable SOCRATA_USERNAME
    -SocrataPassword $Env:API_KEY_SECRET           # Optional; if not supplied, this is looked up from the env variable SOCRATA_PASSWORD
```

[Data Management Experience]: https://support.socrata.com/hc/en-us/articles/115016067067-Using-the-Socrata-Data-Management-Experience
[updates]: #update-an-existing-dataset

## Other resources

* [Dataset Management API: Publishing]
* [Socrata Knowledge Base]
* [dev.socrata.com]
  + [Libraries and SDKs]

[Socrata Knowledge Base]: https://support.socrata.com
[dev.socrata.com]: https://dev.socrata.com
[Dataset Management API: Publishing]: https://socratapublishing.docs.apiary.io
[Libraries and SDKs]: https://dev.socrata.com/libraries
