# Script to locate files within the filesystem.
#
# Either provide a list of filenames in a text file (-filelist [filename]).
# Or provide an existing directory containing files to be found (-filelistDir [Directory]).
# Optionally provide the directory to be searched, defaulting to the current directory.
#
# By default, the full path of all files found will be output.
# Where "-filelistDir" is used, files in this directory will be excluded from the output.
# If "-showFound $true" is used a unique list of filenames found will be output.
# If "-showMissing $true" is used a unique list of filenames not found will be output.
param (
        [string]$filelist,
        [string]$filelistDir,
        [string]$searchDir = ".",
        [bool]$showFound = $false,
        [bool]$showMissing = $false
      )

if ([string]::IsNullOrEmpty($filelist) -And [string]::IsNullOrEmpty($filelistDir))
{
    write-host "Error: No files to find.  Provide 'filelist' or 'filelistDir' parameters." -foregroundcolor red
        exit -1
}

if (![string]::IsNullOrEmpty($filelistDir))
{
    $filelistDir = resolve-path $filelistDir
    $filelistDir = $filelistDir.trim('\')

    # Retrieve a list of files from the directory provided.
    $files = [System.Collections.ArrayList](Get-ChildItem -Path $filelistDir -Recurse -File -Name)
}
else
{
    $files = [System.Collections.ArrayList](Get-Content $filelist)
}

# Look for the files
$foundFiles = @{}
foreach ($file in Get-ChildItem -Path $searchDir -Recurse -File)
{
    foreach ($filename in $files)
    {
        if ($file.Name -eq $filename)
        {
            if (($file.Directory -as [string]) -ne $filelistDir)
            {
                if (!$foundFiles.ContainsKey($file.fullname))
                {
                    $foundFiles[$file.fullname] = [System.Collections.ArrayList]@()
                }
                [void]$foundFiles[$file.fullname].Add($file)
            }
        }
    }
}

# Show full path to all found files.
if ($showFound -eq $false -and $showMissing -eq $false)
{
    foreach($foundFile in $foundFiles.GetEnumerator() | sort-object -property key)
    {
        if (($foundFile.Value.Directory -as [string]) -ne $filelistDir)
        {
            write-output $foundfile.Value.fullname
        }
    }
}

if ($showFound -eq $true)
{
    $uniqueFiles = @{}
    foreach($foundFile in $foundFiles.Values)
    {
        if (($foundFile.Directory -as [string]) -ne $filelistDir)
        {
            $uniqueFiles[$foundFile.Name] = $foundFile
        }
    }

    foreach($file in $uniqueFiles.GetEnumerator() | sort-object -property key)
    {
        write-output $file.Value.name
    }
}

if ($showMissing -eq $true)
{
    # Find the missing files
    $missingFiles = $files
    foreach($foundFile in $foundFiles.Values)
    {
        if (($foundFile.Directory -as [string]) -ne $filelistDir)
        {
            $missingFiles.Remove($foundFile.name)
        }
    }

    $uniqueFiles = @{}
    foreach($file in $missingFiles)
    {
        $uniqueFiles[$file] = $true
    }

    # Show the missing files
    foreach($file in $uniqueFiles.GetEnumerator() | sort-object -property key)
    {
        write-output $file.Key
    }
}
