#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($TestConfig = Get-TestConfig).Defaults
)

Describe "Copy-DbaSpConfigure" -Tag "UnitTests" {
    Context "Parameter validation" {
        BeforeAll {
            $command = Get-Command Copy-DbaSpConfigure
            $expected = $TestConfig.CommonParameters
            $expected += @(
                "Source",
                "SourceSqlCredential",
                "Destination",
                "DestinationSqlCredential",
                "ConfigName",
                "ExcludeConfigName",
                "EnableException",
                "Confirm",
                "WhatIf"
            )
        }

        It "Has parameter: <_>" -ForEach $expected {
            $command | Should -HaveParameter $PSItem
        }

        It "Should have exactly the number of expected parameters ($($expected.Count))" {
            $hasParams = $command.Parameters.Values.Name
            Compare-Object -ReferenceObject $expected -DifferenceObject $hasParams | Should -BeNullOrEmpty
        }
    }
}

Describe "Copy-DbaSpConfigure" -Tag "IntegrationTests" {
    Context "When copying configuration with the same properties" {
        BeforeAll {
            $sourceConfig = Get-DbaSpConfigure -SqlInstance $TestConfig.instance1 -ConfigName RemoteQueryTimeout
            $destConfig = Get-DbaSpConfigure -SqlInstance $TestConfig.instance2 -ConfigName RemoteQueryTimeout
            $sourceConfigValue = $sourceConfig.ConfiguredValue
            $destConfigValue = $destConfig.ConfiguredValue

            # Set different values to ensure they don't match
            if ($sourceConfigValue -and $destConfigValue) {
                $newValue = $sourceConfigValue + $destConfigValue
                $null = Set-DbaSpConfigure -SqlInstance $TestConfig.instance2 -ConfigName RemoteQueryTimeout -Value $newValue
            }
        }

        AfterAll {
            if ($destConfigValue -and $destConfigValue -ne $sourceConfigValue) {
                $null = Set-DbaSpConfigure -SqlInstance $TestConfig.instance2 -ConfigName RemoteQueryTimeout -Value $destConfigValue
            }
        }

        It "Should start with different values" {
            $config1 = Get-DbaSpConfigure -SqlInstance $TestConfig.instance1 -ConfigName RemoteQueryTimeout
            $config2 = Get-DbaSpConfigure -SqlInstance $TestConfig.instance2 -ConfigName RemoteQueryTimeout
            $config1.ConfiguredValue | Should -Not -Be $config2.ConfiguredValue
        }

        It "Should copy successfully" {
            $results = Copy-DbaSpConfigure -Source $TestConfig.instance1 -Destination $TestConfig.instance2 -ConfigName RemoteQueryTimeout
            $results.Status | Should -Be "Successful"
        }

        It "Should retain the same properties after copy" {
            $config1 = Get-DbaSpConfigure -SqlInstance $TestConfig.instance1 -ConfigName RemoteQueryTimeout
            $config2 = Get-DbaSpConfigure -SqlInstance $TestConfig.instance2 -ConfigName RemoteQueryTimeout
            $config1.ConfiguredValue | Should -Be $config2.ConfiguredValue
        }

        It "Should not modify the source configuration" {
            $newConfig = Get-DbaSpConfigure -SqlInstance $TestConfig.instance1 -ConfigName RemoteQueryTimeout
            $newConfig.ConfiguredValue | Should -Be $sourceConfigValue
        }
    }
}
