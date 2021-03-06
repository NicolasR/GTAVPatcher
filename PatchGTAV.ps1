Param([string]$patchFolder, [string]$specificVersion)

#############################
#							#
# 		CONFIGURATION		#
#							#
#############################

$rockstarKeyPath = "HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Rockstar Games\Grand Theft Auto V"
$rockstarUpdateFolder = "\\update"
$rockstarDlcFolder = "\\update\\x64\\dlcpacks"
$patchExecs = @(
	"GTA_V_Patch_"
	"GTA_V_Launcher_"
)

$filesToCopyRoot = @(
	"GTA5.exe"
	"PlayGTAV.exe"
)

#############################
#							#
# 		FONCTIONS			#
#							#
#############################

#Récupère le répertoire d'execution courant
function Get-ScriptDirectory
{
  $Invocation = (Get-Variable MyInvocation -Scope 1).Value
  if ($Invocation.MyCommand.Path -eq $null)
  {
  	return ""
  }
  return Split-Path $Invocation.MyCommand.Path
}

#Effectue le patchage de GTAV
function PatchGTAV([string]$srcFolder,[string]$specificVersion)
{
	Write-Host "Répertoire des patchs" $srcFolder
	$installPathKey = (Get-ItemProperty -Path Registry::$rockstarKeyPath -Name "InstallFolder" -ErrorAction SilentlyContinue)
	if ($installPathKey -eq $null)
	{
		Write-Host "Grand Theft Auto V n'a pas été trouvé. Veuillez vous assurer qu'il est bien installé" -ForegroundColor Red
		return
	}

	$installPath = $installPathKey.InstallFolder
	$patchVersionKey = (Get-ItemProperty -Path Registry::$rockstarKeyPath -Name "PatchVersion" -ErrorAction SilentlyContinue)
	$patchVersion = ""
	if ($patchVersionKey -ne $null)
	{
		$patchVersion = $patchVersionKey.PatchVersion
	}

	Write-Host "Répertoire de Grand Theft Auto V:" $installPath -ForegroundColor Green
	if ($patchVersion.Count -eq 0)
	{
		Write-Host "Version inconnue" -ForegroundColor Green
	}
	else
	{
		Write-Host "Version" $patchVersion -ForegroundColor Green
	}

	$patchDirectories = @{}
	$orderedDirectories = New-Object System.Collections.ArrayList
	$regexVersion = [regex]"[1-9]+.[0-9]+.[0-9]+.[0-9]+"
	$patchsToInstall = New-Object System.Collections.ArrayList
	$allDirectories = Get-ChildItem -Directory | %{ 
	    $patchCorrected = $_.Name.Replace("_",".")     
		$matchingPattern = $regexVersion.Match($patchCorrected) 
	    if ($matchingPattern.Success)
	    {
	        $patchValue = $matchingPattern.Value
			$patchDirectories.Add($patchValue, $_.Name)
			$orderedDirectories.Add($patchValue)
			$patchValue
	    }
	}
	if ($allDirectories.Count -eq 0)
	{
	    Write-Host "Aucun patch trouvé, abandon"
	    return
	}

	Write-Host "Les patchs suivants ont été trouvés:" -ForegroundColor Gray
	$orderedDirectories | Sort-Object{[Version]$_} | % { 
		if ([Version]$_ -le [Version]$patchVersion)
		{
			Write-Host $_ "(Déjà installé)" -ForegroundColor Green
		}
		else
		{
			Write-Host $_ -ForegroundColor Gray
			[Void]$patchsToInstall.Add($_)
		}
		
		if ($specificVersion -ne "" -and $specificVersion -eq $_)
		{
			[Void]$patchsToInstall.Add($_)
		}		
	}

	$fullRockstarDlcPath = $installPath + $rockstarDlcFolder
	try
	{
		$patchsToInstall | % {
			Write-Host "Installation du patch" $_ -ForegroundColor Yellow
			$patchPath = $patchDirectories[$_]
			(Get-ChildItem -Path $patchPath -Directory) | % {
				Write-Host "  -- Installation du DLC" $_ -ForegroundColor Yellow
				Copy-Item -Path ($patchPath + "\\" + $_.Name) -Destination $fullRockstarDlcPath -Recurse -Force
				Write-Host "     OK" -ForegroundColor Green
			}
			
			$patchExecs | % {
				$file = Get-ChildItem -Path $patchPath -Name ($_ + "*")
				if ($file -ne $null)
				{
					$executionCommand = $srcFolder+"\\"+$patchPath+"\\"+$file
					Write-Host "  -- Installation de" $executionCommand -ForegroundColor Yellow
					$batfile = [diagnostics.process]::Start($executionCommand, "/S")
					$batfile.WaitForExit()
					Write-Host "     OK" -ForegroundColor Green
				}		
			}
			
			$filesToCopyRoot | % {
				$file = Get-ChildItem -Path $patchPath -Name $_
				if ($file -ne $null)
				{
					Write-Host "  -- Copie du fichier" $_ -ForegroundColor Yellow
					Copy-Item ($patchPath + "\\" + $file) $installPath -Force
					Write-Host "     OK" -ForegroundColor Green
				}		
			}
			
			$file = Get-ChildItem -Path $patchPath -Name "update.rpf"
			if ($file -ne $null)
			{
				Write-Host "  -- Copie de la mise à jour" $file -ForegroundColor Yellow
				Copy-Item ($patchPath + "\\" + $file) ($installPath + "\\" + $rockstarUpdateFolder) -Force
				Write-Host "     OK" -ForegroundColor Green
			}
			
			(Set-ItemProperty -Path Registry::$rockstarKeyPath -Name "PatchVersion" -Value "$_" -ErrorAction SilentlyContinue)
			Write-Host "Patch" $_ "installé" -ForegroundColor Green
			Write-Host ""
		}
	}
	catch
	{
		$ErrorMessage = $_.Exception.Message
		Write-Host "Une erreur est survenue pendant l'installation" -ForegroundColor Red
		Write-Host $ErrorMessage -ForegroundColor Red
	}
}

#############################
#							#
# 		SCRIPT				#
#							#
#############################


if ($patchFolder -eq "")
{
	$patchFolder = Get-ScriptDirectory
}
cd $patchFolder

# Get the ID and security principal of the current user account
$myWindowsID=[System.Security.Principal.WindowsIdentity]::GetCurrent()
$myWindowsPrincipal=new-object System.Security.Principal.WindowsPrincipal($myWindowsID)

# Get the security principal for the Administrator role
$adminRole=[System.Security.Principal.WindowsBuiltInRole]::Administrator

# Check to see if we are currently running "as Administrator"
if ($myWindowsPrincipal.IsInRole($adminRole))
{
   # We are running "as Administrator" - so change the title and background color to indicate this
   $Host.UI.RawUI.WindowTitle = $myInvocation.MyCommand.Definition + "(Elevated)"
   $Host.UI.RawUI.BackgroundColor = "DarkBlue"
   clear-host
}
else
{
   # We are not running "as Administrator" - so relaunch as administrator
   # Create a new process object that starts PowerShell
   $newProcess = new-object System.Diagnostics.ProcessStartInfo "PowerShell";

   # Specify the current script path and name as a parameter
   $command = $myInvocation.MyCommand.Definition
   $newProcess.Arguments =  @(
        '-NoProfile',
        '-NoExit',
        '-File',
        "`"$($command)`"",
        "`"$patchFolder`"",
		"`"$specificVersion`""
    )
	   
   # Indicate that the process should be elevated
   $newProcess.Verb = "runas";

   # Start the new process
   [System.Diagnostics.Process]::Start($newProcess);

   # Exit from the current, unelevated, process
   exit
}

# Run your code that needs to be elevated here
PatchGTAV $patchFolder $specificVersion
Write-Host -NoNewLine "Appuyez sur une touche pour continuer..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")