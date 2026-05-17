Describe "BicepConsoleTTK" {
    BeforeAll {
        Remove-Module -Name BicepConsoleTTK -ErrorAction SilentlyContinue
        Import-Module "$PSScriptRoot/../src/BicepConsoleTTK" -Force
    }

    Context "Basic evaluation" {

        It "should evaluate a standalone expression without any imports" {

            $result = Invoke-BicepExpression -Expression "concat('hello', '-', 'world')"

            $result | Should -Be "'hello-world'"
        }

        It "should evaluate a user-defined function imported from a single Bicep file" {

            $bicepImports = Import-Bicep "import {coreParams, newCoreParams} from '$PSScriptRoot/../examples/Types.bicep'"

            $expression = "newCoreParams('ukwest', 'ukw', 'dev', 'myproject')"
            $result = Invoke-BicepExpression -BicepImports $bicepImports -Expression $expression

            $expected = "{`n  location: 'ukwest'`n  locationShortName: 'ukw'`n  environment: 'dev'`n  projectPrefix: 'myproject'`n}"
            $result | Should -Be $expected
        }

        It "should evaluate an expression using declarations imported from multiple Bicep files" {

            $bicepImports = Import-Bicep @(
                "import {coreParams, newCoreParams} from '$PSScriptRoot/../examples/Types.bicep'",
                "import {basicResource} from '$PSScriptRoot/../examples/NamingFunctions.bicep'"
            )

            $expression = "basicResource('aks', newCoreParams('ukwest', 'ukw', 'dev', 'myproject'))"
            $result = Invoke-BicepExpression -BicepImports $bicepImports -Expression $expression

            $result | Should -Be "'aks-myproject-dev-ukwest'"
        }

        It "should support setup declarations to pre-declare variables before the main expression" {

            $bicepImports = Import-Bicep @(
                "Import {coreParams, newCoreParams} from '$PSScriptRoot/../examples/Types.bicep'",
                "Import {basicResource} from '$PSScriptRoot/../examples/NamingFunctions.bicep'"
            )

            $setupDeclarations = @(
                "var projectNameStart = 'helloworld'",
                "var projectNameComplete = '`${projectNameStart}bicep'", # NOTE: $ must be escaped with a backtick inside PS double-quoted strings, otherwise PS evaluates it before Bicep sees it
                "var coreParameters coreParams = newCoreParams('ukwest', 'ukw', 'dev', projectNameComplete)"
            )
            $expression = "basicResource('aks', coreParameters)"
            $result = Invoke-BicepExpression -b $bicepImports -s $setupDeclarations -e $expression

            $result | Should -Be "'aks-helloworldbicep-dev-ukwest'"
        }

        It "should support wildcard import to bring in all members from a file" {

            $bicepImports = Import-Bicep "import * from '$PSScriptRoot/../examples/Types.bicep'"

            $expression = "newCoreParams('ukwest', 'ukw', 'dev', 'myproject')"
            $result = Invoke-BicepExpression -BicepImports $bicepImports -Expression $expression

            $expected = "{`n  location: 'ukwest'`n  locationShortName: 'ukw'`n  environment: 'dev'`n  projectPrefix: 'myproject'`n}"
            $result | Should -Be $expected
        }

        It "should accept pipeline input for import strings" {

            $bicepImports = "import {coreParams, newCoreParams} from '$PSScriptRoot/../examples/Types.bicep'" | Import-Bicep

            $expression = "newCoreParams('ukwest', 'ukw', 'dev', 'myproject')"
            $result = Invoke-BicepExpression -BicepImports $bicepImports -Expression $expression

            $expected = "{`n  location: 'ukwest'`n  locationShortName: 'ukw'`n  environment: 'dev'`n  projectPrefix: 'myproject'`n}"
            $result | Should -Be $expected
        }
    }

    Context "NamingFunctions" {
        BeforeAll {
            $script:namingImports = Import-Bicep @(
                "import {coreParams, newCoreParams} from '$PSScriptRoot/../examples/Types.bicep'",
                "import {basicResource, unlocalisedBasicResource, csResource, resourceGroup, resourceGroupNonEnvSpecific, storageAccountResource} from '$PSScriptRoot/../examples/NamingFunctions.bicep'"
            )
        }

        It "basicResource should include resourceAbbreviation, projectPrefix, environment and location" {

            $result = Invoke-BicepExpression -BicepImports $script:namingImports `
                -Expression "basicResource('aks', newCoreParams('ukwest', 'ukw', 'dev', 'myproject'))"

            $result | Should -Be "'aks-myproject-dev-ukwest'"
        }

        It "unlocalisedBasicResource should omit location" {

            $result = Invoke-BicepExpression -BicepImports $script:namingImports `
                -Expression "unlocalisedBasicResource('aks', newCoreParams('ukwest', 'ukw', 'dev', 'myproject'))"

            $result | Should -Be "'aks-myproject-dev'"
        }

        It "csResource should include contextName between projectPrefix and environment" {

            $result = Invoke-BicepExpression -BicepImports $script:namingImports `
                -Expression "csResource('aks', newCoreParams('ukwest', 'ukw', 'dev', 'myproject'), 'networking')"

            $result | Should -Be "'aks-myproject-networking-dev-ukwest'"
        }

        It "resourceGroup should use rg- prefix and include contextName" {

            $result = Invoke-BicepExpression -BicepImports $script:namingImports `
                -Expression "resourceGroup('networking', newCoreParams('ukwest', 'ukw', 'dev', 'myproject'))"

            $result | Should -Be "'rg-myproject-networking-dev-ukwest'"
        }

        It "resourceGroupNonEnvSpecific should omit environment and suffix with -shared" {

            $result = Invoke-BicepExpression -BicepImports $script:namingImports `
                -Expression "resourceGroupNonEnvSpecific('networking', newCoreParams('ukwest', 'ukw', 'dev', 'myproject'))"

            $result | Should -Be "'rg-myproject-networking-ukwest-shared'"
        }

        It "storageAccountResource without contextName should concatenate prefix, environment and locationShortName without separators" {

            $result = Invoke-BicepExpression -BicepImports $script:namingImports `
                -Expression "storageAccountResource(newCoreParams('ukwest', 'ukw', 'dev', 'myproject'), null)"

            $result | Should -Be "'stmyprojectdevukw'"
        }

        It "storageAccountResource with contextName should insert contextName between projectPrefix and environment" {

            $result = Invoke-BicepExpression -BicepImports $script:namingImports `
                -Expression "storageAccountResource(newCoreParams('ukwest', 'ukw', 'dev', 'myproject'), 'blob')"

            $result | Should -Be "'stmyprojectblobdevukw'"
        }
    }

    Context "Error handling" {

        It "should throw when the Bicep expression contains an error" {

            { Invoke-BicepExpression -Expression "undeclaredFunction()" } | Should -Throw "*Bicep console error*"
        }

        It "should include the offending expression in the error message without raw tilde characters" {

            $err = { Invoke-BicepExpression -Expression "undeclaredFunction()" } | Should -Throw -PassThru
            $err.Exception.Message | Should -BeLike "*undeclaredFunction*"
            $err.Exception.Message | Should -Not -BeLike "*~~~~*"
        }

        It "should throw a helpful error when the bicep CLI is not on PATH" {

            InModuleScope BicepConsoleTTK {
                Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'bicep' }
                { Invoke-BicepExpression -Expression "concat('a', 'b')" } | Should -Throw "*bicep CLI not found*"
            }
        }
    }

    Context "Import-Bicep validation" {

        It "should throw when the referenced file does not exist" {

            { Import-Bicep "import {foo} from 'nonexistent.bicep'" } | Should -Throw "*File not found*"
        }

        It "should warn when a named member is not found in the file" {

            Import-Bicep "import {nonExistentMember} from '$PSScriptRoot/../examples/Types.bicep'" -WarningVariable importWarnings | Out-Null
            $importWarnings | Should -Not -BeNullOrEmpty
            "$importWarnings" | Should -BeLike "*nonExistentMember*"
        }

        It "should not emit duplicate declarations when the same member is imported more than once" {

            $bicepImports = Import-Bicep @(
                "import * from '$PSScriptRoot/../examples/Types.bicep'",
                "import {coreParams} from '$PSScriptRoot/../examples/Types.bicep'"
            )
            # A duplicate would cause bicep console to error with 'already declared'
            $expression = "newCoreParams('ukwest', 'ukw', 'dev', 'myproject')"
            $result = Invoke-BicepExpression -BicepImports $bicepImports -Expression $expression
            $expected = "{`n  location: 'ukwest'`n  locationShortName: 'ukw'`n  environment: 'dev'`n  projectPrefix: 'myproject'`n}"
            $result | Should -Be $expected
        }
    }

    Context "Variables" {
        BeforeAll {
            # mandatoryTags is intentionally excluded here — it references deployment() which is
            # a deployment-time function not available in the Bicep console REPL.
            $script:variableImports = Import-Bicep "import {keyVaultSecretsUserRoleDefId, environmentConfig, subnetConfigurations} from '$PSScriptRoot/../examples/Variables.bicep'"
        }

        It "keyVaultSecretsUserRoleDefId should return the expected GUID string" {

            $result = Invoke-BicepExpression -BicepImports $script:variableImports -Expression "keyVaultSecretsUserRoleDefId"

            $result | Should -Be "'4633458b-17de-408a-b874-0445c86b69e6'"
        }

        It "environmentConfig should expose per-environment SKU values" {

            $result = Invoke-BicepExpression -BicepImports $script:variableImports -Expression "environmentConfig.dev.sku"

            $result | Should -Be "'Basic'"
        }

        It "subnetConfigurations should contain the expected subnet entries" {

            $result = Invoke-BicepExpression -BicepImports $script:variableImports -Expression "subnetConfigurations[0].name"

            $result | Should -Be "'web-subnet'"
        }

        It "mandatoryTags should throw because deployment() is not valid in the Bicep console REPL" {

            $mandatoryTagsImport = Import-Bicep "import {mandatoryTags} from '$PSScriptRoot/../examples/Variables.bicep'"
            { Invoke-BicepExpression -BicepImports $mandatoryTagsImport -Expression "mandatoryTags" } | Should -Throw "*Bicep console error*"
        }
    }

    Context "Shared Functions" {
        BeforeAll {
            $script:functionsImports = Import-Bicep "import {GetAIIngestionURL} from '$PSScriptRoot/../examples/Functions.bicep'"
        }

        It "should extract the ingestion endpoint URL and append the v2/track path" {

            $connStr = 'InstrumentationKey=00000000-0000-0000-0000-000000000000;IngestionEndpoint=https://eastus.in.applicationinsights.azure.com/;LiveEndpoint=https://eastus.livediagnostics.monitor.azure.com/;ApplicationId=11111111-1111-1111-1111-111111111111'
            $result = Invoke-BicepExpression -BicepImports $script:functionsImports `
                -Expression "GetAIIngestionURL('$connStr')"

            $result | Should -Be "'https://eastus.in.applicationinsights.azure.com/v2/track'"
        }

        It "should work when IngestionEndpoint is the first segment in the connection string" {

            $connStr = 'IngestionEndpoint=https://westeurope.in.applicationinsights.azure.com/;InstrumentationKey=00000000-0000-0000-0000-000000000000;LiveEndpoint=https://westeurope.livediagnostics.monitor.azure.com/;ApplicationId=11111111-1111-1111-1111-111111111111'
            $result = Invoke-BicepExpression -BicepImports $script:functionsImports `
                -Expression "GetAIIngestionURL('$connStr')"

            $result | Should -Be "'https://westeurope.in.applicationinsights.azure.com/v2/track'"
        }

        It "should work when IngestionEndpoint is the last segment in the connection string" {

            $connStr = 'InstrumentationKey=00000000-0000-0000-0000-000000000000;LiveEndpoint=https://uksouth.livediagnostics.monitor.azure.com/;ApplicationId=11111111-1111-1111-1111-111111111111;IngestionEndpoint=https://uksouth.in.applicationinsights.azure.com/'
            $result = Invoke-BicepExpression -BicepImports $script:functionsImports `
                -Expression "GetAIIngestionURL('$connStr')"

            $result | Should -Be "'https://uksouth.in.applicationinsights.azure.com/v2/track'"
        }
    }

    Context "ConvertTo-BicepConsoleResult" {

        BeforeAll {
            $script:converterImports = Import-Bicep "import {coreParams, newCoreParams} from '$PSScriptRoot/../examples/Types.bicep'"
            # apiOperationDefinition pulls in its *[]? element-type dependencies (queryParameter,
            # templateParameter, header, response) automatically via Import-Bicep's dep resolution.
            $script:apimImports = Import-Bicep "import {apiOperationDefinition} from '$PSScriptRoot/../examples/Types.bicep'"
        }

        It "should convert null to the string 'null'" {

            $actual   = Invoke-BicepExpression -Expression "null"
            $expected = ConvertTo-BicepConsoleResult -Value $null

            $actual | Should -Be $expected
        }

        It "should convert [bool] true to the string 'true'" {

            $actual   = Invoke-BicepExpression -Expression "true"
            $expected = ConvertTo-BicepConsoleResult -Value $true

            $actual | Should -Be $expected
        }

        It "should convert [bool] false to the string 'false'" {

            $actual   = Invoke-BicepExpression -Expression "false"
            $expected = ConvertTo-BicepConsoleResult -Value $false

            $actual | Should -Be $expected
        }

        It "should convert an integer to its numeric string representation" {

            $actual   = Invoke-BicepExpression -Expression "42"
            $expected = ConvertTo-BicepConsoleResult -Value 42

            $actual | Should -Be $expected
        }

        It "should wrap a string in single quotes" {

            $actual   = Invoke-BicepExpression -Expression "'hello'"
            $expected = ConvertTo-BicepConsoleResult -Value 'hello'

            $actual | Should -Be $expected
        }

        It "should escape internal single quotes in a string by doubling them" {

            # The Bicep console REPL parses 'it''s a test' as two separate expressions
            # ('it' and 's a test'), so '' cannot be round-tripped through the console.
            # This test verifies the PS-level escaping behaviour of ConvertTo-BicepConsoleResult directly.
            $result = ConvertTo-BicepConsoleResult -Value "it's a test"

            $result | Should -Be "'it''s a test'"
        }

        It "should convert an [ordered] hashtable to a newline-delimited object string" {

            $actual = Invoke-BicepExpression -BicepImports $script:converterImports `
                -Expression "newCoreParams('ukwest', 'ukw', 'dev', 'myproject')"
            $expected = ConvertTo-BicepConsoleResult ([ordered]@{
                location          = 'ukwest'
                locationShortName = 'ukw'
                environment       = 'dev'
                projectPrefix     = 'myproject'
            })

            $actual | Should -Be $expected
        }

        It "should convert a [pscustomobject] to a newline-delimited object string" {

            $actual = Invoke-BicepExpression -BicepImports $script:converterImports `
                -Expression "newCoreParams('ukwest', 'ukw', 'dev', 'myproject')"
            $expected = ConvertTo-BicepConsoleResult ([pscustomobject]@{
                location          = 'ukwest'
                locationShortName = 'ukw'
                environment       = 'dev'
                projectPrefix     = 'myproject'
            })

            $actual | Should -Be $expected
        }

        It "should throw when given an unordered [hashtable]" {

            { ConvertTo-BicepConsoleResult -Value @{ key = 'value' } } | Should -Throw "*[ordered]*"
        }

        It "should convert a PS array to a newline-delimited array string" {

            $actual   = Invoke-BicepExpression -Expression "['alpha', 'beta', 'gamma']"
            $expected = ConvertTo-BicepConsoleResult -Value @('alpha', 'beta', 'gamma')

            $actual | Should -Be $expected
        }

        It "should render nested objects with correct two-space indentation per depth level" {

            $setup  = @("var obj = { outer: 'value', nested: { inner: 'deep' } }")
            $actual = Invoke-BicepExpression -SetupDeclarations $setup -Expression "obj"
            $expected = ConvertTo-BicepConsoleResult ([ordered]@{
                outer  = 'value'
                nested = [ordered]@{ inner = 'deep' }
            })

            $actual | Should -Be $expected
        }

        It "should accept pipeline input" {

            $actual   = Invoke-BicepExpression -Expression "'pipeline-value'"
            $expected = 'pipeline-value' | ConvertTo-BicepConsoleResult

            $actual | Should -Be $expected
        }

        It "should produce output that matches the actual Bicep console result (round-trip)" {

            $actual = Invoke-BicepExpression -BicepImports $script:converterImports `
                -Expression "newCoreParams('ukwest', 'ukw', 'dev', 'myproject')"
            $expected = ConvertTo-BicepConsoleResult ([ordered]@{
                location          = 'ukwest'
                locationShortName = 'ukw'
                environment       = 'dev'
                projectPrefix     = 'myproject'
            })

            $actual | Should -Be $expected
        }

        It "should handle a deeply nested APIM-style object with arrays of objects and a string array at multiple depth levels" {

            # Depth map:
            #  0  op (apiOperationDefinition)
            #  1    name, properties
            #  2      displayName/method/urlTemplate/description, templateParameters[], request, responses[]
            #  3        templateParameters[0] object,  request.queryParameters[], request.headers[],  responses[0/1] object
            #  4          templateParameter props,  queryParameters[0] object,  headers[0] object,  response props
            #  5            queryParameter props,  header props including values[]
            #  6              values[] items ('abc', 'def')
            $setup = @(
                "var op apiOperationDefinition = { name: 'get-customer', properties: { displayName: 'Get Customer', method: 'GET', urlTemplate: '/customers/{customerId}', description: 'Retrieves a customer by ID', templateParameters: [{ name: 'customerId', type: 'string', required: true }], request: { queryParameters: [{ name: 'includeOrders', type: 'bool', required: false }], headers: [{ name: 'x-correlation-id', type: 'string', required: false, values: ['abc', 'def'] }] }, responses: [{ statusCode: 200 }, { statusCode: 404 }] } }"
            )

            $actual   = Invoke-BicepExpression -BicepImports $script:apimImports -SetupDeclarations $setup -Expression "op"
            $expected = ConvertTo-BicepConsoleResult ([ordered]@{
                name       = 'get-customer'
                properties = [ordered]@{
                    displayName        = 'Get Customer'
                    method             = 'GET'
                    urlTemplate        = '/customers/{customerId}'
                    description        = 'Retrieves a customer by ID'
                    templateParameters = @(
                        [ordered]@{
                            name     = 'customerId'
                            type     = 'string'
                            required = $true
                        }
                    )
                    request            = [ordered]@{
                        queryParameters = @(
                            [ordered]@{
                                name     = 'includeOrders'
                                type     = 'bool'
                                required = $false
                            }
                        )
                        headers         = @(
                            [ordered]@{
                                name     = 'x-correlation-id'
                                type     = 'string'
                                required = $false
                                values   = @('abc', 'def')
                            }
                        )
                    }
                    responses          = @(
                        [ordered]@{ statusCode = 200 }
                        [ordered]@{ statusCode = 404 }
                    )
                }
            })

            $actual | Should -Be $expected
        }
    }

    Context "ConvertTo-BicepLiteral" {

        BeforeAll {
            $script:literalConverterImports = Import-Bicep "import {coreParams, newCoreParams} from '$PSScriptRoot/../examples/Types.bicep'"
            $script:literalApimImports      = Import-Bicep "import {apiOperationDefinition} from '$PSScriptRoot/../examples/Types.bicep'"
        }

        It "should produce the same output as ConvertTo-BicepConsoleResult for null" {

            ConvertTo-BicepLiteral $null | Should -Be (ConvertTo-BicepConsoleResult $null)
        }

        It "should produce the same output as ConvertTo-BicepConsoleResult for bool true and false" {

            ConvertTo-BicepLiteral $true  | Should -Be (ConvertTo-BicepConsoleResult $true)
            ConvertTo-BicepLiteral $false | Should -Be (ConvertTo-BicepConsoleResult $false)
        }

        It "should produce the same output as ConvertTo-BicepConsoleResult for an integer" {

            ConvertTo-BicepLiteral 99 | Should -Be (ConvertTo-BicepConsoleResult 99)
        }

        It "should produce the same output as ConvertTo-BicepConsoleResult for a string" {

            ConvertTo-BicepLiteral 'hello' | Should -Be (ConvertTo-BicepConsoleResult 'hello')
        }

        It "should throw when given an unordered [hashtable]" {

            { ConvertTo-BicepLiteral @{ key = 'value' } } | Should -Throw "*[ordered]*"
        }

        It "should accept pipeline input" {

            $result = 'pipe-test' | ConvertTo-BicepLiteral

            $result | Should -Be "'pipe-test'"
        }

        It "should produce a literal usable as a typed setup declaration (round-trip)" {

            # Embed ConvertTo-BicepLiteral in the setup string via PS subexpression
            $data   = [ordered]@{
                location          = 'ukwest'
                locationShortName = 'ukw'
                environment       = 'dev'
                projectPrefix     = 'myproject'
            }
            $setup  = @("var core coreParams = $(ConvertTo-BicepLiteral $data)")
            $actual = Invoke-BicepExpression -BicepImports $script:literalConverterImports -SetupDeclarations $setup -Expression "core"

            $expected = ConvertTo-BicepConsoleResult $data

            $actual | Should -Be $expected
        }

        It "should produce output identical to ConvertTo-BicepConsoleResult for a deeply nested APIM-style object" {

            $data = [ordered]@{
                name       = 'get-customer'
                properties = [ordered]@{
                    displayName        = 'Get Customer'
                    method             = 'GET'
                    urlTemplate        = '/customers/{customerId}'
                    description        = 'Retrieves a customer by ID'
                    templateParameters = @(
                        [ordered]@{ name = 'customerId'; type = 'string'; required = $true }
                    )
                    request            = [ordered]@{
                        queryParameters = @(
                            [ordered]@{ name = 'includeOrders'; type = 'bool'; required = $false }
                        )
                        headers         = @(
                            [ordered]@{ name = 'x-correlation-id'; type = 'string'; required = $false; values = @('abc', 'def') }
                        )
                    }
                    responses          = @(
                        [ordered]@{ statusCode = 200 }
                        [ordered]@{ statusCode = 404 }
                    )
                }
            }

            ConvertTo-BicepLiteral $data | Should -Be (ConvertTo-BicepConsoleResult $data)
        }

        It "should produce a literal usable as a typed APIM setup declaration (feature-request round-trip)" {

            # This is the exact scenario from the feature request: instead of hand-crafting a
            # single-line Bicep string, embed ConvertTo-BicepLiteral in the setup declaration
            # via a PS subexpression. The Bicep console tolerates the multi-line literal because
            # it waits for braces to balance before evaluating.
            $setup = @(
                "var op apiOperationDefinition = $(ConvertTo-BicepLiteral ([ordered]@{
                    name       = 'get-customer'
                    properties = [ordered]@{
                        displayName        = 'Get Customer'
                        method             = 'GET'
                        urlTemplate        = '/customers/{customerId}'
                        description        = 'Retrieves a customer by ID'
                        templateParameters = @(
                            [ordered]@{ name = 'customerId'; type = 'string'; required = $true }
                        )
                        request            = [ordered]@{
                            queryParameters = @(
                                [ordered]@{ name = 'includeOrders'; type = 'bool'; required = $false }
                            )
                            headers = @(
                                [ordered]@{ name = 'x-correlation-id'; type = 'string'; required = $false; values = @('abc', 'def') }
                            )
                        }
                        responses = @(
                            [ordered]@{ statusCode = 200 }
                            [ordered]@{ statusCode = 404 }
                        )
                    }
                }))"
            )

            $actual   = Invoke-BicepExpression -BicepImports $script:literalApimImports -SetupDeclarations $setup -Expression "op"
            $expected = ConvertTo-BicepConsoleResult ([ordered]@{
                name       = 'get-customer'
                properties = [ordered]@{
                    displayName        = 'Get Customer'
                    method             = 'GET'
                    urlTemplate        = '/customers/{customerId}'
                    description        = 'Retrieves a customer by ID'
                    templateParameters = @(
                        [ordered]@{
                            name     = 'customerId'
                            type     = 'string'
                            required = $true
                        }
                    )
                    request            = [ordered]@{
                        queryParameters = @(
                            [ordered]@{
                                name     = 'includeOrders'
                                type     = 'bool'
                                required = $false
                            }
                        )
                        headers         = @(
                            [ordered]@{
                                name     = 'x-correlation-id'
                                type     = 'string'
                                required = $false
                                values   = @('abc', 'def')
                            }
                        )
                    }
                    responses          = @(
                        [ordered]@{ statusCode = 200 }
                        [ordered]@{ statusCode = 404 }
                    )
                }
            })

            $actual | Should -Be $expected
        }
    }
}