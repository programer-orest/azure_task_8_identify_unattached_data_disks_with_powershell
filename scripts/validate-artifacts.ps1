param(
    [Parameter(Mandatory=$false, ValueFromPipeline=$true)]
    [bool]$DownloadArtifacts=$true
)


# default script values 
$taskName = "task8"

$artifactsConfigPath = "$PWD/artifacts.json"
$resourcesTemplateName = "exported-template.json"
$tempFolderPath = "$PWD/temp"

if ($DownloadArtifacts) { 
    Write-Output "Reading config" 
    $artifactsConfig = Get-Content -Path $artifactsConfigPath | ConvertFrom-Json 

    Write-Output "Checking if temp folder exists"
    if (-not (Test-Path "$tempFolderPath")) { 
        Write-Output "Temp folder does not exist, creating..."
        New-Item -ItemType Directory -Path $tempFolderPath
    }

    Write-Output "Downloading artifacts"

    if (-not $artifactsConfig.resourcesTemplate) { 
        throw "Artifact config value 'resourcesTemplate' is empty! Please make sure that you executed the script 'scripts/generate-artifacts.ps1', and commited your changes"
    }
    Invoke-WebRequest -Uri $artifactsConfig.resourcesTemplate -OutFile "$tempFolderPath/$resourcesTemplateName" -UseBasicParsing

}

Write-Output "Validating artifacts"
$TemplateFileText = [System.IO.File]::ReadAllText("$tempFolderPath/$resourcesTemplateName")
$TemplateObject = ConvertFrom-Json $TemplateFileText -AsHashtable

$virtualMachine = ( $TemplateObject.resources | Where-Object -Property type -EQ "Microsoft.Compute/virtualMachines" )
if ($virtualMachine) {
    if ($virtualMachine.name.Count -eq 1) { 
        Write-Output "`u{2705} Checked if Virtual Machine exists - OK."
    }  else { 
        Write-Output `u{1F914}
        throw "More than one Virtual Machine resource was found in the VM resource group. Please delete all un-used VMs and try again."
    }
} else {
    Write-Output `u{1F914}
    throw "Unable to find Virtual Machine in the task resource group. Please make sure that you created the Virtual Machine and try again."
}

$disk = ( $TemplateObject.resources | Where-Object -Property type -EQ "Microsoft.Compute/disks" )
if ($disk) { 
    if ($disk.name.Count -eq 1) { 
        Write-Output "`u{2705} Checked if disk resources exist in the task resource group - OK."
    }  else { 
        Write-Output `u{1F914}
        throw "Unable to verify Azure Disk resources in the task resource group. Please make sure the task resource group has exactly 2 Azure Disk resources (one for OS disk and one for the deattached data disk) and try again. "
    }

} else {
    Write-Output `u{1F914}
    throw "Unable to find Azure Disk resources in the task resource group. Please make sure the task resource group has 2 Azure Disk resources (one for OS disk and one for the deattached data disk) and try again."
}

# if ($disk.properties.diskState -ne "Attached") { 
#     Write-Output "`u{2705} Checked if the data disk is unattached - OK."
# } else { 
#     Write-Output `u{1F914}
#     throw "Unable to verify the state of the data disk. Please make sure that you deatached the data disk from the VM and try again. "
# }

try {
    $taskResult = Get-Content "$PWD/result.json" | ConvertFrom-Json 

    if ($taskResult.Name.Count -eq 1 ) { 
        Write-Output "`u{2705} Checked the result.json has only 1 data disk - OK."
    } else { 
        Write-Output `u{1F914}
        throw "Unable to verify disk object in the result.json. According to the task requirements you supposed to have only one unattached data disk, which should be identified by the Powershell script (but in the result.json file you have $($taskResult.Name.Count) objects). Please check your infrastructure (task rg should have only 2 Azure Disk resources) and the script and try again."
    }

    if ($taskResult.DiskState) { 
        if ($taskResult.DiskState -eq "Unattached") { 
            Write-Output "`u{2705} Checked the result.json has unattached disk - OK."
        } else {
            Write-Output `u{1F914}
            throw "Unable to verify disk state in the result.json file. File should have only unattached data disks, found disk with state '$($taskResult.DiskState)'. Please check your script and try again."
        }
    } else { 
        Write-Output `u{1F914}
        throw "Unable to find the DiskState property in the object, saved to the result.json file. Please make sure that you are saving AzureDisk object (or list of AzureDisk objects) in your script and try again."
    }
}
catch {
    throw "Unable to read disk information data from file 'result.json'. Please check if your script saved the result to the file in JSON format and try again. Original error: $($_)"
}


## Validate the task script

$match = Select-String -Path "$PWD/task.ps1"  -Pattern "Get-AzDisk"
if ($match.Count -eq 1) { 
    if ($match.Line.Contains("-DiskName")) { 
        Write-Output `u{1F914}
        throw "Unable to verify the task script. Script is expected to use comandlet 'Get-AzDisk' without filtering by disk name ('DiskName' parameter). Please check your script and try again."
    } else { 
        Write-Output "`u{2705} Checked the usage of 'Get-AzDisk' comandlet - OK."
    }
} else { 
    Write-Output `u{1F914}
    throw "Unable to verify the task script. Script is expected to use comandlet 'Get-AzDisk' only once, to load information about the disks." 
}

$match = Select-String -Path "$PWD/task.ps1" -Pattern "DiskState" 
if (-not $match) { 
    $match = Select-String -Path "$PWD/task.ps1" -Pattern "ManagedBy" 
}
if ($match.Count -ne 0) { 
    Write-Output "`u{2705} Checked the script for the filtering by DiskState or ManagedBy - OK."
} else { 
    Write-Output `u{1F914}
    throw "Unable to verify the task script. Script is expected to filter the disks by the 'DiskState' or by 'ManagedBy' property. Please check the script and try again." 
}

Write-Output ""
Write-Output "`u{1F973} Congratulations! All tests passed!"
