﻿ function Get-DbaXEventsSession {
 <#
.SYNOPSIS
Get a list of Extended Events Sessions

.DESCRIPTION
Retrieves a list of Extended Events Sessions

.PARAMETER SqlInstance
The SQL Instances that you're connecting to.

.PARAMETER Credential
Credential object used to connect to the SQL Server as a different user

.NOTES
Author: Klaas Vandenberghe ( @PowerDBAKlaas )
	
dbatools PowerShell module (https://dbatools.io)
Copyright (C) 2016 Chrissy LeMaire
This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.

	
.LINK
https://dbatools.io/Get-DbaXEventsSession

.EXAMPLE
Get-DbaXEventsSession -SqlServer ServerA\sql987

Returns a custom object with ComputerName, SQLInstance, Session, StartTime, Status and other properties.

.EXAMPLE
Get-DbaXEventsSession -SqlServer ServerA\sql987 | Format-Table ComputerName, SQLInstance, Session, Status -AutoSize

Returns a formatted table displaying ComputerName, SQLInstance, Session, and Status.

.EXAMPLE
'ServerA\sql987','ServerB' | Get-DbaXEventsSession

Returns a custom object with ComputerName, SQLInstance, Session, StartTime, Status and other properties, from multiple SQL Instances.
#>
    [CmdletBinding()]
    param (
		[parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[Alias("ServerInstance", "SqlServer")]
		[string[]]$SqlInstance,
		[PsCredential]$SqlCredential
    )
    BEGIN {
        if ([System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Management.XEvent") -eq $null)
		{
			throw "SMO version is too old. To collect Extended Events, you must have Shared Management Objects 2008 R2 or higher installed."
		}
    }
    PROCESS {
        foreach ( $instance in $SqlInstance )
        {
            Write-Verbose "Connecting to $instance ."
			try
			{
				$server = Connect-SqlServer -SqlServer $instance -SqlCredential $Credential -ErrorAction SilentlyContinue
                Write-Verbose "SQL Instance $instance is version $($server.versionmajor) ."
            }
            catch
            {
                Write-Warning " Failed to connect to $instance ."
                continue
            }
            if($server.versionmajor -ge 11)
            {
		        $SqlConn = $server.ConnectionContext.SqlConnectionObject
		        $SqlStoreConnection = New-Object Microsoft.SqlServer.Management.Sdk.Sfc.SqlStoreConnection $SqlConn
		        $XEStore = New-Object  Microsoft.SqlServer.Management.XEvent.XEStore $SqlStoreConnection
                Write-Verbose "Getting XEvents Sessions on $instance ."

                try
                {
                $XEStore.sessions | 
                    ForEach-Object {
                        [PSCustomObject]@{
                            ComputerName = $server.NetName
                            SQLInstance = $server.ServiceName
                            Session = $_.Name
                            Status = switch ( $_.IsRunning ) { $true {"Running"} $false {"Stopped"} }
                            StartTime = $_.StartTime
                            AutoStart = $_.AutoStart
                            State = $_.State
                            Targets = $_.Targets
                            Events = $_.Events
                            MaxMemory = $_.MaxMemory
                            MaxEventSize = $_.MaxEventSize
                            }
                    }
	            }
                catch
                {
                Write-Warning "Failed to get XEvents Sessions on $instance ."
                }
            }
            else
            {
                Write-Warning "SQL Instance $instance is SQL Version $($server.versionmajor) . This is not supported."
            }
        }
    }
    END {}
}