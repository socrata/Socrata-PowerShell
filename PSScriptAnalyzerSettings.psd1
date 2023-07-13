@{
    # Rules to exclude
    ExcludeRules = @(
        "PSAvoidUsingConvertToSecureStringWithPlainText",
        "PSUseDeclaredVarsMoreThanAssignments",
        "PSUseShouldProcessForStateChangingFunctions",
        "PSUseSingularNouns"
    )
    Rules = @{
        PSUseCompatibleCommands = @{
            Enable = $true

            # PowerShell platforms with which to check compatibility
            TargetProfiles = @(
                "win-8_x64_10.0.14393.0_5.1.14393.2791_x64_4.0.30319.42000_framework",
                "win-8_x64_10.0.14393.0_6.2.4_x64_4.0.30319.42000_core",
                "win-8_x64_10.0.14393.0_7.0.0_x64_3.1.2_core"
            )
        }
        PSUseCompatibleSyntax = @{
            Enable = $true

            # PowerShell versions to target
            TargetVersions = @(
                "5.1",
                "6.2",
                "7.0"
            )
        }
    }
}
