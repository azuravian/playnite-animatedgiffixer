function GetGameMenuItems
{
    param(
        $MenuArgs
    )

    $menuItem = New-Object Playnite.SDK.Plugins.ScriptGameMenuItem
    $menuItem.Description = "Fix Animated Gifs"
	$menuItem.FunctionName = "FixAnimatedGifs"

    return $menuItem
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
			$targetpng = Join-Path $gifpath -ChildPath "target.png"
			$images = @()
			wget -O $tempgif $match.ToString()
			if ($tempgif -like "*gif*"){
				& "$MagickExecutablePath" convert -coalesce "$tempgif" "$targetpng"
				$frames = & "$MagickExecutablePath" convert $tempgif"[-1]" -format %[scene] info:
			}
			elseif ($tempgif -like "*png*"){
				& "$MagickExecutablePath" convert -coalesce apng:"$tempgif" "$targetpng"
				$frames = (Get-ChildItem $gifpath | Measure-Object).Count
			}
			if ([int]$frames -lt 12){
				continue
			}
			$div = [int][Math]::Floor([int]$frames / 12)
			$constdiv = $div
			while ($div -lt $frames){
				$img = "target-" + $div + ".png"
				$img = Join-Path $gifpath $img
				$images += $img
				$div += $constdiv
			}
			OpenWindow $match $imgnum
			$imgnum += 1
			
		}
		$game.Description = $global:description
		if ($global:gamebool -eq $true){
			$gamecount += 1
		}
		$total += 1
		$PlayniteApi.Database.Games.Update($game)
	}
	Clear-Folder
	$PlayniteApi.Dialogs.ShowMessage("$total selected games have been inspected. `n$gamecount games were updated. `nModified a total of $imgcount images.", "Fix Animated Gifs")
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
			Remove-Item -ErrorAction Ignore -Recurse $FixAniGifFolder
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
		$ni = $imgnum.ToString() + ".png"
		$newfile = Join-Path $newpath -ChildPath $($ni)
		
		
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