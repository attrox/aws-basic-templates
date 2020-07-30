# Get disk number from EBS Device Name
function Get-DiskNumber {
    param([string]$deviceName)
    $instanceId = (Invoke-WebRequest -Uri 'http://169.254.169.254/latest/meta-data/instance-id' -UseBasicParsing).Content
    $volumeId = ((Get-EC2Volume -Filter @{ Name="attachment.instance-id"; Values=$instanceId }).Attachment | Where-Object -FilterScript {$_.Device -Eq $deviceName }).VolumeId
    if ($volumeId -eq $null) {
        throw "Volume " + $deviceName + " not found."
    }
    (Get-Disk | Where-Object -FilterScript {$_.SerialNumber -Like ($volumeId -replace '-','') + "*"}).Number
}

$driveD = Get-DiskNumber "xvdf"
$driveE = Get-DiskNumber "xvdg"
$driveF = Get-DiskNumber "xvdh"
$driveG = Get-DiskNumber "xvdi"

# Getting the DSC Cert Encryption Thumbprint to Secure the MOF File
$thumbprint = [string](get-childitem -path cert:\LocalMachine\My | where { $_.subject -eq "CN=MySelfSignedCert" }).Thumbprint
$ConfigurationData = @{
    AllNodes = @(
        @{
            NodeName="*"
            CertificateFile = "c:\windows\temp\selfsignedcert.cer"
            Thumbprint = $thumbprint
            PSDscAllowDomainUser = $true
        },
        @{
            NodeName = 'localhost'
        }
    )
}

Install-Module -Name StorageDsc -Force

Configuration Disk_InitializeDataDisk
{
    Import-DSCResource -ModuleName StorageDsc

    Node 'localhost' {
        WaitForDisk 'xvdf' {
             DiskId = $driveD
             RetryIntervalSec = 60
             RetryCount = 60
        }

        Disk 'DVolume' {
             DiskId = $driveD
             DriveLetter = 'D'
             PartitionStyle = 'GPT'
             FSFormat = 'NTFS'
             DependsOn = '[WaitForDisk]xvdf'
        }

        WaitForDisk 'xvdg' {
             DiskId = $driveE
             RetryIntervalSec = 60
             RetryCount = 60
        }

        Disk 'EVolume' {
             DiskId = $driveE
             DriveLetter = 'E'
             PartitionStyle = 'GPT'
             FSFormat = 'NTFS'
             DependsOn = '[WaitForDisk]xvdg'
        }

        WaitForDisk 'xvdh' {
            DiskId = $driveF
            RetryIntervalSec = 60
            RetryCount = 60
        }

        Disk 'FVolume' {
            DiskId = $driveF
            DriveLetter = 'F'
            PartitionStyle = 'GPT'
            FSFormat = 'NTFS'
            DependsOn = '[WaitForDisk]xvdh'
       }

        WaitForDisk 'xvdi' {
            DiskId = $driveG
            RetryIntervalSec = 60
            RetryCount = 60
        }

        Disk 'GVolume' {
            DiskId = $driveG
            DriveLetter = 'G'
            PartitionStyle = 'GPT'
            FSFormat = 'NTFS'
            DependsOn = '[WaitForDisk]xvdi'
       }
    }
}

Disk_InitializeDataDisk -OutputPath 'C:\windows\temp\InitializeDisk-DSC' -ConfigurationData $ConfigurationData

Start-DscConfiguration 'C:\windows\temp\InitializeDisk-DSC' -Wait -Verbose -Force
