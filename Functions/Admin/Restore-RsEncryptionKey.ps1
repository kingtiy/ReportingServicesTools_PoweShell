# Copyright (c) 2016 Microsoft Corporation. All Rights Reserved.
# Licensed under the MIT License (MIT)

function Restore-RSEncryptionKey
{
    <#
        .SYNOPSIS
            This script restores the SQL Server Reporting Services encryption key.
        
        .DESCRIPTION
            This script restores encryption key for SQL Server Reporting Services. This key is needed in order to read all the encrypted content stored in the Reporting Services Catalog database.
        
        .PARAMETER Password
            Specify the password that was used when the encryption key was backed up.
        
        .PARAMETER KeyPath
            Specify the path to where the encryption key is stored.
        
        .PARAMETER ReportServerInstance
            Specify the name of the SQL Server Reporting Services Instance.
            Use the "Connect-RsReportServer" function to set/update a default value.
        
        .PARAMETER ReportServerVersion
            Specify the version of the SQL Server Reporting Services Instance.
            Use the "Connect-RsReportServer" function to set/update a default value.
        
        .PARAMETER ComputerName
            The Report Server to target.
            Use the "Connect-RsReportServer" function to set/update a default value.
        
        .PARAMETER Credential
            The credentials with which to connect to the Report Server.
            Use the "Connect-RsReportServer" function to set/update a default value.
        
        .EXAMPLE
            Restore-RSEncryptionKey -Password 'Enter Your Password' -KeyPath 'C:\ReportingServices\Default.snk'
            Description
            -----------
            This command will restore the encryption key to the default instance from SQL Server 2016 Reporting Services
        
        .EXAMPLE
            Restore-RSEncryptionKey -ReportServerInstance 'SQL2012' -ReportServerVersion '11' -Password 'Enter Your Password' -KeyPath 'C:\ReportingServices\Default.snk'
            Description
            -----------
            This command will restore the encryption key to the named instance (SQL2012) from SQL Server 2012 Reporting Services
    #>

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param
    (
        [Parameter(Mandatory = $True)]
        [string]
        $Password,
        
        [Parameter(Mandatory = $True)]
        [string]
        $KeyPath,
        
        [Alias('SqlServerInstance')]
        [string]
        $ReportServerInstance,
        
        [Alias('SqlServerVersion')]
        [Microsoft.ReportingServicesTools.SqlServerVersion]
        $ReportServerVersion,
        
        [string]
        $ComputerName,
        
        [System.Management.Automation.PSCredential]
        $Credential
    )
    
    if ($PSCmdlet.ShouldProcess((Get-ShouldProcessTargetWmi -BoundParameters $PSBoundParameters), "Restore encryptionkey from file $KeyPath"))
    {
        $rsWmiObject = New-RsConfigurationSettingObjectHelper -BoundParameters $PSBoundParameters

        $KeyPath = Resolve-Path $KeyPath
        
        $reportServerService = 'ReportServer'
        
        if ($rsWmiObject.InstanceName -ne "MSSQLSERVER")
        {
            $reportServerService = $reportServerService + '$' + $rsWmiObject.InstanceName
        }
        
        Write-Verbose "Checking if key file path is valid..."
        if (-not (Test-Path $KeyPath))
        {
            throw "No key was found at the specified location: $path"
        }
        
        try
        {
            $keyBytes = [System.IO.File]::ReadAllBytes($KeyPath)
        }
        catch
        {
            throw
        }
        
        Write-Verbose "Restoring encryption key..."
        $restoreKeyResult = $rsWmiObject.RestoreEncryptionKey($keyBytes, $keyBytes.Length, $Password)
        
        if ($restoreKeyResult.HRESULT -eq 0)
        {
            Write-Verbose "Success!"
        }
        else
        {
            throw "Failed to restore the encryption key! Errors: $($restoreKeyResult.ExtendedErrors)"
        }
        
        try
        {
            $service = Get-Service -Name $reportServerService -ComputerName $rsWmiObject.PSComputerName -ErrorAction Stop
            Write-Verbose "Stopping Reporting Services Service..."
            $service.Stop()
            $service.WaitForStatus([System.ServiceProcess.ServiceControllerStatus]::Stopped)
            
            Write-Verbose "Starting Reporting Services Service..."
            $service.Start()
            $service.WaitForStatus([System.ServiceProcess.ServiceControllerStatus]::Running)
        }
        catch
        {
            throw (New-Object System.Exception("Failed to restart Report Server database service. Manually restart it for the change to take effect! $($_.Exception.Message)", $_.Exception))
        }
    }
}
