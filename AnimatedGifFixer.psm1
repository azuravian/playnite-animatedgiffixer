function GetGameMenuItems
{
    param(
        $MenuArgs
    )

    $menuItem = New-Object Playnite.SDK.Plugins.ScriptGameMenuItem
    $menuItem.Description = "Fix Animated GIFs"
	$menuItem.FunctionName = "FixAnimatedGifs"
	$menuItem.MenuSection = "Animated GIF Fixer"
	$menuItem1 = New-Object Playnite.SDK.Plugins.ScriptGameMenuItem
    $menuItem1.Description = "Tag Animated GIFs"
	$menuItem1.FunctionName = "TagAnimatedGifs"
	$menuItem1.MenuSection = "Animated GIF Fixer"
    return $menuItem, $menuItem1
}

function FixAnimatedGifs
{
	param(
        $scriptMainMenuItemActionArgs
    )
# Load assemblies
    Add-Type -AssemblyName PresentationCore
    Add-Type -AssemblyName PresentationFramework
	
	$GameDatabase = $PlayniteApi.MainView.SelectedGames
	Clear-Folder
	$global:imgcount = 0
	$gamecount = 0
	$total = 0
	
	# Try to get magick.exe path via registry
    $Key = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, [Microsoft.Win32.RegistryView]::Registry64)
	$RegSubKey =  $Key.OpenSubKey("Software\ImageMagick\Current")
	
    if ($RegSubKey)
    {
        $RegInstallDir = $RegSubKey.GetValue("BinPath")
        if ($RegInstallDir)
        {
            $MagickExecutable = Join-Path -Path $RegInstallDir -ChildPath 'magick.exe'
            if (Test-Path $MagickExecutable)
            {
                $MagickExecutablePath = $MagickExecutable
                $__logger.Info("Fix Animated Gifs - Found executable Path via registry in `"$MagickExecutablePath`".")
            }
        }
    }

    if ($null -eq $MagickExecutablePath)
    {
        # Set Magick Executable Path via user Input
        $MagickConfigPath = Join-Path -Path $CurrentExtensionDataPath -ChildPath 'ConfigMagicPath.ini'
        if (Test-Path $MagickConfigPath)
        {
            $MagickExecutablePath = [System.IO.File]::ReadAllLines($MagickConfigPath)
        }
        else
        {
            $PlayniteApi.Dialogs.ShowMessage("Select ImageMagick executable", "Fix Animated Gifs")
            $MagickExecutablePath = $PlayniteApi.Dialogs.SelectFile("magick|magick.exe")
            if (!$MagickExecutablePath)
            {
                exit
            }
            [System.IO.File]::WriteAllLines($MagickConfigPath, $MagickExecutablePath)
            $__logger.Info("Fix Animated Gifs - Saved executable Path via user input in `"$MagickExecutablePath`".")
            $PlayniteApi.Dialogs.ShowMessage("Magick executable path saved", "Fix Animated Gifs")
        }

        if (!(Test-Path $MagickExecutablePath))
        {
            [System.IO.File]::Delete($MagickConfigPath)
            $__logger.Info("Fix Animated Gifs - Executable not found in user configured path `"$MagickExecutablePath`".")
            $PlayniteApi.Dialogs.ShowMessage("Magick executable not found in `"$MagickExecutablePath`". Please run the extension again to configure it to the correct location.", "Fix Animated Gifs")
            exit
        }
    }	
	
	foreach ($game in $GameDatabase){
		$global:description = $game.Description
		$global:gamebool = $false
		$regex = '(https?:\/\/)(.[^"]*?)(gif|png|jpg)(.*?)(?=")'
		$RegexMatches = ([regex]$regex).Matches($global:description)
		$imgnum = 0
		$tagMatch = $PlayniteApi.Database.tags.Add('[AGF]')
		$tagId = $tagMatch.Id
		foreach ($match in $RegexMatches){
			$gifpath = New-TemporaryDirectory
			if (!(Test-Path -Path $gifpath))
			{
				mkdir -Path $gifpath
			}
			
			if ($match -like "*gif*" -Or $match -like "*jpg*"){
				$tempgif = Join-Path $gifpath -ChildPath "temp.gif"
			}
			elseif ($match -like "*png*"){
				$tempgif = Join-Path $gifpath -ChildPath "temp.png"
			}
			$guid = New-Guid
			$guid = "$guid.png"
			$targetpng = Join-Path $gifpath -ChildPath $guid
			$images = @()
			wget -O $tempgif $match.ToString()
			if ($tempgif -like "*gif*")
			{
				$anigifs = & "$MagickExecutablePath" identify $tempgif
			}
			elseif ($tempgif -like "*png*")
			{
				$anigifs = & "$MagickExecutablePath" identify apng:$tempgif
			}
			$frames = [int]$anigifs.Count
			if ($frames -lt 12)
			{
				continue
			}
			
			$answer = Show-Gif
			
			if ($answer -eq 7)
			{
				continue
			}
			$div = [int][Math]::Floor($frames / 12)
			$constdiv = $div
			while ($div -lt $frames){
				$img = "target-" + $div + ".png"
				$img = Join-Path $gifpath $img
				$delnum = $div - 1
				& "$MagickExecutablePath" convert "$tempgif[0-$div]" -coalesce -delete "0-$delnum" $img
				$images += $img
				$div += $constdiv
			}
			OpenWindow $match $imgnum
			$imgnum += 1
		}
		$game.Description = $global:description
		if ($global:gamebool -eq $true){
			$gamecount += 1
			$game.tagIds.Remove($tagId)
		}
		$total += 1
		$PlayniteApi.Database.Games.Update($game)
	}
	Clear-Folder
	$PlayniteApi.Dialogs.ShowMessage("$total selected games have been inspected. `n$gamecount games were updated. `nModified a total of $imgcount images.", "Fix Animated Gifs")
}

function TagAnimatedGifs
{
	param(
        $scriptMainMenuItemActionArgs
    )
	# Load assemblies
    Add-Type -AssemblyName PresentationCore
    Add-Type -AssemblyName PresentationFramework
	
	$GameDatabase = $PlayniteApi.MainView.SelectedGames
	$timer = $div = [int]($GameDatabase.Count / 60)
	$gamecount = 0
	$total = 0
	$tagMatch = $PlayniteApi.Database.tags.Add('[AGF]')
    $tagId = $tagMatch.Id
	$PlayniteApi.Dialogs.ShowMessage("Based on the selected games, this process will take approximately $timer minutes.", "Fix Animated Gifs")
	foreach ($game in $GameDatabase)
	{
		try {
			$regex = '(https?:\/\/)(.[^"]*?)(gif|png|jpg)(.*?)(?=")'
			$RegexMatches = ([regex]$regex).Matches($game.Description)
			foreach ($match in $RegexMatches)
			{
				$gifpath = New-TemporaryDirectory
				if (!(Test-Path -Path $gifpath))
				{
					mkdir -Path $gifpath
				}
				
				if ($match -like "*gif*" -Or $match -like "*jpg*")
				{
					$tempgif = Join-Path $gifpath -ChildPath "temp.gif"
				}
				elseif ($match -like "*png*")
				{
					$tempgif = Join-Path $gifpath -ChildPath "temp.png"
				}
				
				wget -O $tempgif $match.ToString()
				
				if ($tempgif -like "*gif*")
				{
					$anigifs = magick identify $tempgif
				}
				elseif ($tempgif -like "*png*")
				{
					$anigifs = magick identify apng:$tempgif
				}
				if ($anigifs.Count -gt 1)
				{
					if ($game.tagIds -notcontains $tagId)
					{
						$gamecount += 1
						# Add tag Id to game
						if ($game.tagIds)
						{
							$game.tagIds += $tagId
						}
						else
						{
							# Fix in case game has null tagIds
							$game.tagIds = $tagId
						}
					}
					$PlayniteApi.Database.Games.Update($game)
					break
				}
			}
			$total += 1
		} catch {
			continue
		}
		Clear-Folder
	}
	$PlayniteApi.Dialogs.ShowMessage("$total selected games have been inspected. `n$gamecount games appear to have animated gifs.  They have had the tag [AGF] added to them.", "Fix Animated Gifs")
}

function Show-Gif {	
	$imgheight = & "$MagickExecutablePath" convert "$tempgif[0]" -format '%h' info:
	$imgwidth = & "$MagickExecutablePath" convert "$tempgif[0]" -format '%w' info:
	$windowheight = [int]$imgheight + 120
	$windowwidth = [int]$imgwidth + 20
	#Create a form
	
	$borderheight = [int]$imgheight + 4
	$borderwidth = [int]$imgwidth + 4
	$gifnum = $imgcount + 1

	Add-Type -AssemblyName System.Windows.Forms
	$Form = New-Object System.Windows.Forms.Form
	$Form.Size = New-Object System.Drawing.Size($windowwidth, $windowheight)
	$Form.StartPosition = "CenterScreen"
	$Form.BackColor = "#FF262f39"
	$Form.FormBorderStyle = "None"

	#Adding some text
	$Form.Text = "GIF Player"
	
	$answer = 7

	$Panel = New-Object System.Windows.Forms.FlowLayoutPanel
	$Panel.AutoScroll = $true
	$Panel.AutoSize = $true
	$Panel.FlowDirection = "TopDown"
	$Panel.WrapContents = $false
	$Panel.Margin = "2,2,2,2"
	
	$Border = New-Object System.Windows.Forms.FlowLayoutPanel
	$Border.BackColor = "white"
	$Border.Margin="8,8,8,8"
	$Border.AutoSize = $true
	
	$ButtonPanel = New-Object System.Windows.Forms.FlowLayoutPanel
	$ButtonPanel.Margin = "10,10,10,10"
	
	$Title = New-Object System.Windows.Forms.Label
	$Title.Location = New-Object System.Drawing.Size(10,10)
	$Title.AutoSize = $true
	$Title.ForeColor = "white"
	$Title.Font = New-Object System.Drawing.Font ("Courier",14, [System.Drawing.Fontstyle]::Bold)
	$Title.Text = "Gif #$gifnum for $game"
	$Title.Margin = "10,0,0,0"
	$Panel.Controls.Add($Title)
	
	#Get the local saved GIF
	$gifBox = New-Object Windows.Forms.picturebox
	$gifLink= (Get-Item -Path $tempgif)
	$img = [System.Drawing.Image]::fromfile($gifLink)
	$gifBox.AutoSize = $true
	$gifBox.Image = $img
	$gifBox.Margin = "4,4,4,4"
	$Border.Controls.Add($gifbox)
	$Panel.Controls.Add($Border)
	
	$Label = New-Object System.Windows.Forms.Label
	$Label.AutoSize = $true
	$Label.ForeColor = "white"
	$Label.Font = New-Object System.Drawing.Font ("Courier",10, [System.Drawing.Fontstyle]::Bold)
	$Label.Text = "Do you want to process this gif?"
	$Label.Margin = "10,0,0,0"
	$Panel.Controls.Add($Label)
	
	$Button1 = New-Object System.Windows.Forms.Button
	#$Button1.Location = New-Object System.Drawing.Point(10,400)
	$Button1.Size = New-Object System.Drawing.Size(80,20)
	$Button1.Text = "Yes"
	$Button1.ForeColor = "white"
	$Button1.BackColor = "#3287e3"
	$ButtonPanel.Controls.Add($Button1)
	
	$Button = New-Object System.Windows.Forms.Button
	#$Button.Location = New-Object System.Drawing.Point(100,400)
	$Button.Size = New-Object System.Drawing.Size(80,20)
	$Button.Text = "No"
	$Button.ForeColor = "white"
	$Button.BackColor = "#3287e3"
	$ButtonPanel.Controls.Add($Button)
	
	$Panel.Controls.Add($ButtonPanel)
	$Form.Controls.Add($Panel)
	
	$Button.Add_Click({
		$Form.DialogResult = 7
	})
	
	$Button1.Add_Click({
		$Form.DialogResult = 6
	})

	#Execute the form
	$Form.ShowDialog()
}

function New-TemporaryDirectory {
    $TempFolder = [System.IO.Path]::GetTempPath()
	$parent = Join-Path $TempFolder -ChildPath "FixAniGif"
	[string]$name = [System.Guid]::NewGuid()
    New-Item -ItemType Directory -Path (Join-Path $parent $name) -Force
}

function Clear-Folder {
	$TempFolder = [System.IO.Path]::GetTempPath()
	$FixAniGifFolder = Join-Path $TempFolder -ChildPath "FixAniGif"
	if (Test-Path -Path $FixAniGifFolder)
	{
		try
		{
			Remove-Item -ErrorAction Ignore -Recurse -Force $FixAniGifFolder
		}
		catch
		{
			$__logger.Info("Fix Animated Gifs - Unable to clear temp folder.")
		}
	}
}

function OpenWindow($match, $imgnum)
{
	$image0 = $images[0]
	$image1 = $images[1]
	$image2 = $images[2]
	$image3 = $images[3]
	$image4 = $images[4]
	$image5 = $images[5]
	$image6 = $images[6]
	$image7 = $images[7]
	$image8 = $images[8]
	$image9 = $images[9]
	$image10 = $images[10]
	$image11 = $images[11]
	
	# Set Xaml
    [xml]$Xaml = @"
<Grid xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
		xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" 
		Margin="20">
	<Grid.Resources>	
		<Style TargetType="TextBlock" BasedOn="{StaticResource BaseTextBlockStyle}" />
	</Grid.Resources>
	<Grid>
		<Grid.RowDefinitions>
			<RowDefinition Height="Auto"/>
			<RowDefinition Height="Auto"/>
			<RowDefinition Height="*"/>
			<RowDefinition Height="Auto"/>
		</Grid.RowDefinitions>
		
		<ListBox Grid.Row="2" Name="ListBoxImages" Margin="0,20,0,0"
				 ScrollViewer.HorizontalScrollBarVisibility="Disabled"
				 BorderThickness="0"
				 ScrollViewer.VerticalScrollBarVisibility="Auto">				 
			<ListBox.ItemsPanel>
				<ItemsPanelTemplate>
					<WrapPanel />
				</ItemsPanelTemplate>
			</ListBox.ItemsPanel>
			<ListBoxItem>
				<Image Source="$image0" Width="{Binding ElementName=Slider, Path=Value}"/>
			</ListBoxItem>
			<ListBoxItem>
				<Image Source="$image1" Width="{Binding ElementName=Slider, Path=Value}" />
			</ListBoxItem>
			<ListBoxItem>
				<Image Source="$image2" Width="{Binding ElementName=Slider, Path=Value}" />
			</ListBoxItem>
			<ListBoxItem>
				<Image Source="$image3" Width="{Binding ElementName=Slider, Path=Value}" />
			</ListBoxItem>
			<ListBoxItem>
				<Image Source="$image4" Width="{Binding ElementName=Slider, Path=Value}" />
			</ListBoxItem>
			<ListBoxItem>
				<Image Source="$image5" Width="{Binding ElementName=Slider, Path=Value}" />
			</ListBoxItem>
			<ListBoxItem>
				<Image Source="$image6" Width="{Binding ElementName=Slider, Path=Value}" />
			</ListBoxItem>
			<ListBoxItem>
				<Image Source="$image7" Width="{Binding ElementName=Slider, Path=Value}" />
			</ListBoxItem>
			<ListBoxItem>
				<Image Source="$image8" Width="{Binding ElementName=Slider, Path=Value}" />
			</ListBoxItem>
			<ListBoxItem>
				<Image Source="$image9" Width="{Binding ElementName=Slider, Path=Value}" />
			</ListBoxItem>
			<ListBoxItem>
				<Image Source="$image10" Width="{Binding ElementName=Slider, Path=Value}" />
			</ListBoxItem>
			<ListBoxItem>
				<Image Source="$image11" Width="{Binding ElementName=Slider, Path=Value}" />
			</ListBoxItem>
		</ListBox>
		<DockPanel Grid.Row="3">
			<Label DockPanel.Dock="Left" FontWeight="Bold" Margin="10,10,10,10">Image Size:</Label>
			<Slider x:Name="Slider"
				Width="700"
				Margin="10,20,10,10"
				Interval="10"
				Maximum="900"
				Minimum="150"
				Value="300"
				TickPlacement="BottomRight"
				TickFrequency="50"/>
			<Button Content="Select Image" Name="ButtonSelectImage"
				DockPanel.Dock="Right" Margin="10,10,10,10"
				IsDefault="False"/>
		</DockPanel>
	</Grid>
</Grid>

"@

    # Load the xaml for controls
    $XMLReader = [System.Xml.XmlNodeReader]::New($Xaml)
    $XMLForm = [Windows.Markup.XamlReader]::Load($XMLReader)

    # Make variables for each control
    $Xaml.FirstChild.SelectNodes("//*[@Name]") | ForEach-Object {Set-Variable -Name $_.Name -Value $XMLForm.FindName($_.Name) }

    # Set Window creation options
    $WindowCreationOptions = New-Object Playnite.SDK.WindowCreationOptions
    $WindowCreationOptions.ShowCloseButton = $true
    $WindowCreationOptions.ShowMaximizeButton = $False
    $WindowCreationOptions.ShowMinimizeButton = $False
	
	# Create window
    $Window = $PlayniteApi.Dialogs.CreateWindow($WindowCreationOptions)
    $Window.Content = $XMLForm
    $Window.Width = 1000
    $Window.Height = 600
    $Window.Title = "Fix Animated Gifs - $game"
    $Window.WindowStartupLocation = "CenterScreen"

    # Handler for pressing "Select Image" button
	
	$ButtonSelectImage.Add_Click(
	{	
		$sel = $ListBoxImages.SelectedIndex.ToString()
		$selpath = $images[$sel]
		$newpath = Join-Path $CurrentExtensionDataPath -ChildPath $($game.Id)
		$nip = "$($([System.IO.Path]::GetRandomFileName()).Split('.')[0]).png"
		$newfile = Join-Path $newpath -ChildPath $($nip)
				
		if (!(Test-Path -Path $newpath))
		{
			mkdir -Path $newpath
		}
		
		
		if (!(Test-Path -Path $newfile))
		{
			[System.IO.File]::Copy($selpath, $newfile)
		}
		
		$global:description = $global:description.replace($match, $newfile)
		$global:imgcount += 1
		$global:gamebool = $true
		$Window.DialogResult = $true
	})
	
    
    # Show Window
    $__logger.Info("Fix Animated Gifs - Opening Window.")
    $Window.ShowDialog()
    $__logger.Info("Fix Animated Gifs - Window closed.")
}