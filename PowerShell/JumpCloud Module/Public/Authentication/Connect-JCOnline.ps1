Function Connect-JCOnline ()
{
    [CmdletBinding(DefaultParameterSetName = 'Interactive')]
    Param
    (
        [Parameter(ParameterSetName = 'force', ValueFromPipelineByPropertyName, HelpMessage = 'Specific to JumpCloud development team to connect to staging and local dev environments.')]
        [Parameter(ParameterSetName = 'Interactive', ValueFromPipelineByPropertyName, HelpMessage = 'Specific to JumpCloud development team to connect to staging and local dev environments.')]
        [ValidateSet('production', 'staging', 'local')]
        [System.String]$JCEnvironment = 'production',
        [Parameter(ParameterSetName = 'force', HelpMessage = 'Using the "-Force" parameter the module update check is skipped. The ''-Force'' parameter should be used when using the JumpCloud module in scripts or other automation environments.')][Switch]$force
    )
    DynamicParam
    {
        $Param_JumpCloudApiKey = @{
            'Name'                            = 'JumpCloudApiKey';
            'Type'                            = [System.String];
            'Position'                        = 0;
            'ValueFromPipelineByPropertyName' = $true;
            'ValidateNotNullOrEmpty'          = $true;
            'ValidateLength'                  = (40, 40);
            'ParameterSets'                   = ('force', 'Interactive');
            'HelpMessage'                     = 'Please enter your JumpCloud API key. This can be found in the JumpCloud admin console within "API Settings" accessible from the drop down icon next to the admin email address in the top right corner of the JumpCloud admin console.';
        }
        $Param_JumpCloudOrgId = @{
            'Name'                            = 'JumpCloudOrgId';
            'Type'                            = [System.String];
            'Position'                        = 1;
            'ValueFromPipelineByPropertyName' = $true;
            'ValidateNotNullOrEmpty'          = $true;
            'ParameterSets'                   = ('force', 'Interactive');
            'HelpMessage'                     = 'Organization Id can be found in the Settings page within the admin console. Only needed for multi tenant admins.';
        }
        # If the $env:JCApiKey is not set then make the JumpCloudApiKey mandatory else set the default value to be the env variable
        If ([System.String]::IsNullOrEmpty($env:JCApiKey))
        {
            $Param_JumpCloudApiKey.Add('Mandatory', $true);
        }
        Else
        {
            $Param_JumpCloudApiKey.Add('Default', $env:JCApiKey);
        }
        # If the $env:JCOrgId is set then set the default value to be the env variable
        If (-not [System.String]::IsNullOrEmpty($env:JCOrgId))
        {
            $Param_JumpCloudOrgId.Add('Default', $env:JCOrgId);
        }
        If ((Get-PSCallStack).Command -like '*MarkdownHelp')
        {
            $JCEnvironment = 'local'
        }
        If ($JCEnvironment -eq "local")
        {
            $Param_ip = @{
                'Name'                            = 'ip';
                'Type'                            = [System.String];
                'ValueFromPipelineByPropertyName' = $true;
                'HelpMessage'                     = 'Enter an IP address';
            }
        }
        # Build output
        # Build parameter array
        $RuntimeParameterDictionary = New-Object -TypeName System.Management.Automation.RuntimeDefinedParameterDictionary
        $ParamVarPrefix = 'Param_'
        Get-Variable -Scope:('Local') | Where-Object { $_.Name -like '*' + $ParamVarPrefix + '*' } | ForEach-Object {
            # Add RuntimeDictionary to each parameter
            $_.Value.Add('RuntimeParameterDictionary', $RuntimeParameterDictionary)
            # Creating each parameter
            $VarName = $_.Name
            $VarValue = $_.Value
            Try
            {
                New-DynamicParameter @VarValue | Out-Null
            }
            Catch
            {
                Write-Error -Message:('Unable to create dynamic parameter:"' + $VarName.Replace($ParamVarPrefix, '') + '"; Error:' + $Error)
            }
        }
        $IndShowMessages = If ([System.String]::IsNullOrEmpty($JumpCloudApiKey) -and [System.String]::IsNullOrEmpty($JumpCloudOrgId) -and -not [System.String]::IsNullOrEmpty($env:JCApiKey) -and -not [System.String]::IsNullOrEmpty($env:JCOrgId))
        {
            $false
        }
        Else
        {
            $true
        }
        Return $RuntimeParameterDictionary
    }
    Begin
    {
        # Debug message for parameter call
        Invoke-Command -ScriptBlock:($ScriptBlock_DefaultDebugMessageBegin) -ArgumentList:($MyInvocation, $PsBoundParameters, $PSCmdlet) -NoNewScope
        Switch ($JCEnvironment)
        {
            'production'
            {
                $global:JCUrlBasePath = "https://console.jumpcloud.com"
            }
            'staging'
            {
                $global:JCUrlBasePath = "https://console.awsstg.jumpcloud.com"
            }
            'local'
            {
                If ($PSBoundParameters['ip'])
                {
                    $global:JCUrlBasePath = $PSBoundParameters['ip']
                }
                Else
                {
                    $global:JCUrlBasePath = "http://localhost"
                }
            }
        }
    }
    Process
    {
        # Load color scheme
        $JCColorConfig = Get-JCColorConfig
        # For DynamicParam with a default value set that value and then convert the DynamicParam inputs into new variables for the script to use
        Invoke-Command -ScriptBlock:($ScriptBlock_DefaultDynamicParamProcess) -ArgumentList:($PsBoundParameters, $PSCmdlet, $RuntimeParameterDictionary) -NoNewScope
        Try
        {
            # Update security protocol
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls, [System.Net.SecurityProtocolType]::Tls12
            #Region Set environment variables that can be used by other scripts
            # If "$JumpCloudApiKey" is populated or if "$env:JCApiKey" is not set
            If (-not [System.String]::IsNullOrEmpty($JumpCloudApiKey))
            {
                # Set $env:JCApiKey
                $env:JCApiKey = $JumpCloudApiKey
                $global:JCAPIKEY = $env:JCApiKey
            }
            # Set $env:JCOrgId in Set-JCOrganization
            $Auth = If ([System.String]::IsNullOrEmpty($JumpCloudOrgId) -and [System.String]::IsNullOrEmpty($env:JCOrgId))
            {
                Set-JCOrganization -JumpCloudApiKey:($env:JCApiKey)
            }
            ElseIf (-not [System.String]::IsNullOrEmpty($JumpCloudOrgId) -and [System.String]::IsNullOrEmpty($env:JCOrgId))
            {
                Set-JCOrganization -JumpCloudApiKey:($env:JCApiKey) -JumpCloudOrgId:($JumpCloudOrgId)
            }
            ElseIf ([System.String]::IsNullOrEmpty($JumpCloudOrgId) -and -not [System.String]::IsNullOrEmpty($env:JCOrgId))
            {
                Set-JCOrganization -JumpCloudApiKey:($env:JCApiKey) -JumpCloudOrgId:($env:JCOrgId)
            }
            ElseIf (-not [System.String]::IsNullOrEmpty($JumpCloudOrgId) -and -not [System.String]::IsNullOrEmpty($env:JCOrgId) -and $JumpCloudOrgId -ne $env:JCOrgId)
            {
                Set-JCOrganization -JumpCloudApiKey:($env:JCApiKey) -JumpCloudOrgId:($JumpCloudOrgId)
            }
            Else
            {
                Write-Debug ('The $JumpCloudOrgId supplied matches existing $env:JCOrgId.')
                Set-JCOrganization -JumpCloudApiKey:($env:JCApiKey) -JumpCloudOrgId:($env:JCOrgId)
            }
            If (-not [System.String]::IsNullOrEmpty($Auth))
            {
                # Each time a new org is selected get settings info
                $global:JCSettingsUrl = $JCUrlBasePath + '/api/settings'
                $global:JCSettings = Invoke-JCApi -Method:('GET') -Url:($JCSettingsUrl)
                #EndRegion Set environment variables that can be used by other scripts
                If (([System.String]::IsNullOrEmpty($JCOrgId)) -or ([System.String]::IsNullOrEmpty($env:JCOrgId)))
                {
                    Write-Error ('Incorrect OrgId OR no network connectivity. You can obtain your Organization Id below your Organization''s Contact Information on the Settings page.')
                    Break
                }
                If (([System.String]::IsNullOrEmpty($JCAPIKEY)) -or ([System.String]::IsNullOrEmpty($env:JCApiKey)))
                {
                    Write-Error ('Incorrect API key OR no network connectivity. To locate your JumpCloud API key log into the JumpCloud admin portal. The API key is located with "API Settings" accessible from the drop down in the top right hand corner of the screen')
                    Break
                }
                # Check for updates to the module and only prompt if user has not been prompted during the session already
                If ($JCEnvironment -ne 'local')
                {
                    If (!($force))
                    {
                        If ([System.String]::IsNullOrEmpty($env:JcUpdateModule) -or $env:JcUpdateModule -eq 'True')
                        {
                            $env:JcUpdateModule = $false
                            Update-JCModule | Out-Null
                        }
                        If ($IndShowMessages)
                        {
                            Write-Host ('Connection Status:') -BackgroundColor:($JCColorConfig.BackgroundColor) -ForegroundColor:($JCColorConfig.ForegroundColor_Header)
                            Write-Host ($JCColorConfig.IndentChar) -BackgroundColor:($JCColorConfig.BackgroundColor) -ForegroundColor:($JCColorConfig.ForegroundColor_Indentation) -NoNewline
                            Write-Host ('Successfully connected to JumpCloud!') -BackgroundColor:($JCColorConfig.BackgroundColor) -ForegroundColor:($JCColorConfig.ForegroundColor_Body)
                            Write-Host ('OrgId:') -BackgroundColor:($JCColorConfig.BackgroundColor) -ForegroundColor:($JCColorConfig.ForegroundColor_Header)
                            Write-Host ($JCColorConfig.IndentChar) -BackgroundColor:($JCColorConfig.BackgroundColor) -ForegroundColor:($JCColorConfig.ForegroundColor_Indentation) -NoNewline
                            Write-Host ($Auth.JCOrgId) -BackgroundColor:($JCColorConfig.BackgroundColor) -ForegroundColor:($JCColorConfig.ForegroundColor_Body)
                            Write-Host ('OrgName:') -BackgroundColor:($JCColorConfig.BackgroundColor) -ForegroundColor:($JCColorConfig.ForegroundColor_Header)
                            Write-Host ($JCColorConfig.IndentChar) -BackgroundColor:($JCColorConfig.BackgroundColor) -ForegroundColor:($JCColorConfig.ForegroundColor_Indentation) -NoNewline
                            Write-Host ($Auth.JCOrgName) -BackgroundColor:($JCColorConfig.BackgroundColor) -ForegroundColor:($JCColorConfig.ForegroundColor_Body)
                        }
                    }
                }
                # Return [PSCustomObject]@{
                    # 'JCApiKey'  = $env:JCApiKey;
                    # 'JCOrgId'   = $Auth.JCOrgId;
                    # 'JCOrgName' = $Auth.JCOrgName;
                # }
            }
            Else
            {
                Write-Error ('Unable to set module authentication')
            }
        }
        Catch
        {
            Write-Error $_
        }
    }
    End
    {
    }
}