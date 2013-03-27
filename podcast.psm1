#requires -version 2.0
<#
.Synopsis
   Downloads Channel 9 Defrag Tool Episode Video
.DESCRIPTION
   Downloads Channel 9 Defrag Tool Episode Video in the format selected and to a given path.
.EXAMPLE
   Downloads all shows in WMV format to the default Downloads Folder for the user.

   Get-DefragToolsShow -All -VideoType wmv

.EXAMPLE
   Downloads only the last show of the series in MP4 format

   Get-DefragToolsShow -Last -VideoType MP4
.NOTES
    Author: Carlos Perez carlos_perez[at]darkoperator.com
#>
function Get-DefragToolsShow 
{
    [CmdletBinding()]
    Param
    (

        # Path to download the episodes.
        [Parameter(Mandatory=$false,
                   Position=0)]
        $Path = "$($env:USERPROFILE)\downloads",

        # Download all the episodes.
        [Parameter(Mandatory=$false,
        ParameterSetName="All")]
        [switch]$All,

        # Download only the last episode.
        [Parameter(Mandatory=$false,
        ParameterSetName="Lastest")]
        [switch]$Lastest,

        # Download only the last episode.
        [Parameter(Mandatory=$false,
        ParameterSetName="List")]
        [switch]$List,

        # Download only the specified episode.
        [Parameter(Mandatory=$false,
        ParameterSetName="Episode")]
        [int32]$EpisodeNumber,

        # The type of video to download.
        [Parameter(Mandatory=$false)]
        [ValidateSet("MP4HD","MP4","WMVHD","WMV")]
        [string]$VideoType =  "MP4HD",

        # Will create the folder if not present.
        [Parameter(Mandatory=$false,
        ParameterSetName="Last")]
        [switch]$Force = $true
        
    )

    Begin
    {
        $WebClient =  New-Object System.Net.WebClient
        $Global:downloadComplete = $false
        
        # Make sure there are no previously registered events.
        Unregister-Event -SourceIdentifier WebClient.DownloadProgressChanged -ErrorAction SilentlyContinue
        Unregister-Event -SourceIdentifier WebClient.DownloadFileComplete -ErrorAction SilentlyContinue


        # Register events for showing progress
        Write-Verbose "Registering event for when tracking when download finishes."
        $eventDataComplete = Register-ObjectEvent $WebClient DownloadFileCompleted `
            -SourceIdentifier WebClient.DownloadFileComplete `
            -Action {$Global:downloadComplete = $true}

        Write-Verbose "Registering event for when tracking when download progress."
        $eventDataProgress = Register-ObjectEvent $WebClient DownloadProgressChanged `
            -SourceIdentifier WebClient.DownloadProgressChanged `
            -Action { $Global:DPCEventArgs = $EventArgs }    

        # Lets change to the proper path
        if (Test-Path $Path)
        {
            $fullpath = (Resolve-Path $Path).Path
            Set-Location $fullpath
        }
        else
        {
            if ($Force)
            {
                New-Item -ItemType directory -Path $Path | out-null
                $fullpath = (Resolve-Path $Path).Path
                Set-Location $fullpath
            }
            else
            {
                Write-Error "Specified path does not exist"
                return
            }
        }
    }
    Process
    {
        switch ($VideoType)
        {
            "MP4HD"  {$feedURL = "http://channel9.msdn.com/Shows/Defrag-Tools/feed/mp4high"} 
            "MP4"    {$feedURL = "http://channel9.msdn.com/Shows/Defrag-Tools/feed/mp4"}
            "WMVHD"  {$feedURL = "http://channel9.msdn.com/Shows/Defrag-Tools/feed/wmvhigh"}
            "WMV"    {$feedURL = "http://channel9.msdn.com/Shows/Defrag-Tools/feed/wmv"}
        }

        $feed = [xml]$WebClient.DownloadString($feedURL)

        switch ($PsCmdlet.ParameterSetName)
        {
            "All"
            {
                foreach ($episode in $feed.rss.channel.Item)
                {
                    # Create a proper URI for parsing
                    $episodeURL = [System.Uri]$episode.enclosure.url

                    # Get the episode file name
                    $file = $episodeURL.Segments[-1]
               
                    #Check if the file exists if it does skip it
                    if (!(Test-Path "$($fullpath)\$($file)"))
                    {
                        Write-Progress -Activity 'Downloading file' -Status $file
                        $WebClient.DownloadFileAsync($episodeURL, "$($fullpath)\$($file)")

                         while (!($Global:downloadComplete)) 
                         {                
                            $pc = $Global:DPCEventArgs.ProgressPercentage
                            if ($pc -ne $null) 
                            {
                                Write-Progress -Activity 'Downloading file' -Status $file -PercentComplete $pc
                            }
                        }
                        $Global:downloadComplete = $false
                    }
                }
            }

            "Lastest"
            {
                $episodeURL = [System.Uri]$feed.rss.channel.Item[0].enclosure.url
                # Get the episode file name
                $file = $episodeURL.Segments[-1]

                #Check if the file exists if it does skip it
                if (!(Test-Path "$($fullpath)\$($file)"))
                {
                    write-verbose "Downloading to $($fullpath)\$($file)"
                    Write-Progress -Activity 'Downloading file' -Status $file
                    $WebClient.DownloadFileAsync($episodeURL, "$($fullpath)\$($file)")
                    # Lets wait for it to finish
                    while (!($Global:downloadComplete)) 
                    {                
                        $pc = $Global:DPCEventArgs.ProgressPercentage
                        if ($pc -ne $null) 
                        {
                            Write-Progress -Activity 'Downloading file' -Status $file -PercentComplete $pc
                        }
                    }
                }
            }

            "List"
            {
                foreach ($episode in $feed.rss.channel.Item)
                {
                    $EpisodeProperties = New-Object -TypeName System.Collections.Specialized.OrderedDictionary
                    $EpisodeProperties.add("Title",$episode.title)
                    $EpisodeProperties.add("Summary",$episode.summary)
                    $EpisodeProperties.add("Category",$episode.category)
                    $EpisodeProperties.add("Link", $episode.link)
                    $EpisodeProperties.add("Duration",$episode.duration) 
                    New-Object -TypeName psobject -Property $EpisodeProperties
                }
            }
            "Episode"
            {
                foreach ($episode in $feed.rss.channel.Item)
                {
                    $EpisodeRegex = [regex]"#$EpisodeNumber -"
                    "#($EpisodeNumber) -"
                    if (Select-String -InputObject $episode.title -Pattern $EpisodeRegex)
                    {
                        # Create a proper URI for parsing
                        $episodeURL = [System.Uri]$episode.enclosure.url

                        # Get the episode file name
                        $file = $episodeURL.Segments[-1]
               
                        #Check if the file exists if it does skip it
                        if (!(Test-Path "$($fullpath)\$($file)"))
                        {
                            Write-Progress -Activity 'Downloading file' -Status $file
                            $WebClient.DownloadFileAsync($episodeURL, "$($fullpath)\$($file)")

                             while (!($Global:downloadComplete)) 
                             {                
                                $pc = $Global:DPCEventArgs.ProgressPercentage
                                if ($pc -ne $null) 
                                {
                                    Write-Progress -Activity 'Downloading file' -Status $file -PercentComplete $pc
                                }
                            }
                            $Global:downloadComplete = $false
                        }
                    }
                }
            }

        }
    }
    End
    {
        Unregister-Event -SourceIdentifier WebClient.DownloadProgressChanged
        Unregister-Event -SourceIdentifier WebClient.DownloadFileComplete
        $Global:downloadComplete = $null
        $Global:DPCEventArgs = $null
        [GC]::Collect()    
    }
}


<#
.Synopsis
   Downloads PowerScripting Podcast Audio Episode
.DESCRIPTION
   Downloads PowerScripting Podcast Audio Episodes to a given path.
.EXAMPLE
   Downloads all episodes to the default Downloads Folder for the user.

   Get-PowerScriptingPodcast -All 
.EXAMPLE
   List available episodes.

   Get-PowerScriptingPodcast -List

.EXAMPLE
   Downloads an episode given the index from the list.

   Get-PowerScriptingPodcast -EpisodeIndex 227
.NOTES
    Author: Carlos Perez carlos_perez[at]darkoperator.com
#>
function Get-PowerScriptingPodcast
{
    [CmdletBinding()]
    Param
    (

        # Path to download the episodes.
        [Parameter(Mandatory=$false,
                   Position=0)]
        $Path = "$($env:USERPROFILE)\downloads",

        # Download all the episodes.
        [Parameter(Mandatory=$false,
        ParameterSetName="All")]
        [switch]$All,

        # Download only the last episode.
        [Parameter(Mandatory=$false,
        ParameterSetName="Lastest")]
        [switch]$Lastest,

        # Download only the last episode.
        [Parameter(Mandatory=$false,
        ParameterSetName="List")]
        [switch]$List,

        # Download only the specified episode.
        [Parameter(Mandatory=$false,
        ParameterSetName="Episode")]
        [int32]$EpisodeIndex,

        # Will create the folder if not present.
        [Parameter(Mandatory=$false,
        ParameterSetName="Last")]
        [switch]$Force = $true
        
    )

    Begin
    {
        $WebClient =  New-Object System.Net.WebClient
        $Global:downloadComplete = $false
        
        # Make sure there are no previously registered events.
        Unregister-Event -SourceIdentifier WebClient.DownloadProgressChanged -ErrorAction SilentlyContinue
        Unregister-Event -SourceIdentifier WebClient.DownloadFileComplete -ErrorAction SilentlyContinue


        # Register events for showing progress
        Write-Verbose "Registering event for when tracking when download finishes."
        $eventDataComplete = Register-ObjectEvent $WebClient DownloadFileCompleted `
            -SourceIdentifier WebClient.DownloadFileComplete `
            -Action {$Global:downloadComplete = $true}

        Write-Verbose "Registering event for when tracking when download progress."
        $eventDataProgress = Register-ObjectEvent $WebClient DownloadProgressChanged `
            -SourceIdentifier WebClient.DownloadProgressChanged `
            -Action { $Global:DPCEventArgs = $EventArgs }    

        # Lets change to the proper path
        if (Test-Path $Path)
        {
            $fullpath = (Resolve-Path $Path).Path
            Set-Location $fullpath
        }
        else
        {
            if ($Force)
            {
                New-Item -ItemType directory -Path $Path | out-null
                $fullpath = (Resolve-Path $Path).Path
                Set-Location $fullpath
            }
            else
            {
                Write-Error "Specified path does not exist"
                return
            }
        }
    }
    Process
    {
        
        $feed = [xml]$WebClient.DownloadString("http://feeds.feedburner.com/Powerscripting?format=xml")

        switch ($PsCmdlet.ParameterSetName)
        {
            "All"
            {
                foreach ($episode in $feed.rss.channel.Item)
                {
                    # Create a proper URI for parsing
                    $episodeURL = [System.Uri]$episode.enclosure.url

                    # Get the episode file name
                    $file = $episodeURL.Segments[-1]
               
                    #Check if the file exists if it does skip it
                    if (!(Test-Path "$($fullpath)\$($file)"))
                    {
                        Write-Progress -Activity 'Downloading file' -Status $file
                        $WebClient.DownloadFileAsync($episodeURL, "$($fullpath)\$($file)")

                         while (!($Global:downloadComplete)) 
                         {                
                            $pc = $Global:DPCEventArgs.ProgressPercentage
                            if ($pc -ne $null) 
                            {
                                Write-Progress -Activity 'Downloading file' -Status $file -PercentComplete $pc
                            }
                        }
                        $Global:downloadComplete = $false
                    }
                }
            }

            "Lastest"
            {
                $episodeURL = [System.Uri]$feed.rss.channel.Item[0].enclosure.url
                # Get the episode file name
                $file = $episodeURL.Segments[-1]

                #Check if the file exists if it does skip it
                if (!(Test-Path "$($fullpath)\$($file)"))
                {
                    write-verbose "Downloading to $($fullpath)\$($file)"
                    Write-Progress -Activity 'Downloading file' -Status $file
                    $WebClient.DownloadFileAsync($episodeURL, "$($fullpath)\$($file)")
                    # Lets wait for it to finish
                    while (!($Global:downloadComplete)) 
                    {                
                        $pc = $Global:DPCEventArgs.ProgressPercentage
                        if ($pc -ne $null) 
                        {
                            Write-Progress -Activity 'Downloading file' -Status $file -PercentComplete $pc
                        }
                    }
                }
            }

            "List"
            {
                $episode = $feed.rss.channel.Item

                for ($i=0; $i -le ($episode.count -1); $i++)
                {
                    $EpisodeProperties = New-Object -TypeName System.Collections.Specialized.OrderedDictionary
                    $EpisodeProperties.add("Index",$i)
                    $EpisodeProperties.add("Title",$episode[$i].title)
                    $EpisodeProperties.add("Summary",$episode[$i].summary)
                    $EpisodeProperties.add("Link", $episode[$i].link)
                    $EpisodeProperties.add("Duration",$episode[$i].duration)
                    $EpisodeProperties.add("ReleaseDate",$episode[$i].pubDate)
                    New-Object -TypeName psobject -Property $EpisodeProperties
                }
            }
            "Episode"
            {
                $episode = $feed.rss.channel.Item
                
                # Create a proper URI for parsing
                $episodeURL = [System.Uri]$episode[$EpisodeIndex].enclosure.url

                # Get the episode file name
                $file = $episodeURL.Segments[-1]
               
                #Check if the file exists if it does skip it
                if (!(Test-Path "$($fullpath)\$($file)"))
                {
                    Write-Progress -Activity 'Downloading file' -Status $file
                    $WebClient.DownloadFileAsync($episodeURL, "$($fullpath)\$($file)")

                        while (!($Global:downloadComplete)) 
                        {                
                        $pc = $Global:DPCEventArgs.ProgressPercentage
                        if ($pc -ne $null) 
                        {
                            Write-Progress -Activity 'Downloading file' -Status $file -PercentComplete $pc
                        }
                    }
                    $Global:downloadComplete = $false
                }
                    
            }

        }
    }
    End
    {
        Unregister-Event -SourceIdentifier WebClient.DownloadProgressChanged
        Unregister-Event -SourceIdentifier WebClient.DownloadFileComplete
        $Global:downloadComplete = $null
        $Global:DPCEventArgs = $null
        [GC]::Collect()    
    }
}