#Module: MobileUtils
#Author: Sunit Joshi, sunit.joshi@hexagon.com

function Run-EmuCmd()
{
	<#
	.Synopsis
   Runs a cmd against the virtual device. If you don't specify a cmd,
	it runs the getprop cmd to dump out all device properties.
	.EXAMPLE
	This runs the UNIX df command to list disk usage. The virtual deviceId can be obtained by running adb devices cmd
   Run-EmuCmd -avd emulator-5554 -cmd df
	#>
	[CmdletBinding()]
    param
	(
		[Parameter(Mandatory=$false)]
		[string]$avd="emulator-5554",
		[Parameter(Mandatory=$false)]
		[string]$cmd="getprop"
	)
	if($avd) {
		icm  {adb -s $avd shell `"$cmd`"}
	} else {
		icm {adb shell `"$cmd`"}
	}
}

function Get-EmuLocale
{
	<#
	.Synopsis
	Gets the locale of Android emulator device
	.EXAMPLE
    Get-EmuLocale -avd emulator-5554
	#>
	[CmdletBinding()]
    param
	(
		[Parameter(Mandatory=$false)]
		[string]$avd="emulator-5554"
	)
	$p=$null
	if(Test-Path variable:global:Matches) {
		$Matches.Clear()
	}
	$p = Run-EmuCmd $avd | Where { $_ -match "persist\.sys\.language|persist\.sys\.locale"}
	if($p -match ":\s+\[(?<locale>.+)\]") {
		$Matches.locale
	} else {
		[String]::Empty
	}
}

function Set-EmuLocale
{
	<#
	.Synopsis
    Sets the locale of Android emulator device. Default is neutral english (EN).
	Valid choices are EN, DE, JA, IR, RU.
	.EXAMPLE
	This sets the locale to DE (German)
    Set-EmuLocale DE
	#>
	[CmdletBinding()]
    param
    (
		[Parameter(Mandatory=$false)]
		[string]$avd="emulator-5554",
		[Parameter(Mandatory=$false)]
		[ValidateSet("EN", "DE", "JA", "IR", "UND")]
		[string]$Locale="EN"
	)
	Run-EmuCmd $avd "am broadcast -a com.android.intent.action.SET_LOCALE --es com.android.intent.extra.LOCALE $Locale"
}

function Get-NeutralLocales
{
	<#
	.Synopsis
   Displays Neutral Cultures that have name without '-' separator
	.EXAMPLE
   Get-Locales
#>
	[CultureInfo]::GetCultures('NeutralCulture') | Where-Object {($_.Name.Length -gt 0) -and ($_.Name -notmatch "-")}
}

function Get-UniqueLocaleDecSep
{
	<#
	.Synopsis
   Displays a subset of Cultures that have unique DecimalSeparator
	.EXAMPLE
   Get-UniqueLocaleDecSep
	#>
	Get-NeutralLocales | Sort-Object @{E={$_.NumberFormat.PercentDecimalSeparator}; Descending=$true} -Unique | `
	  Select-Object Name, @{N='DecimalSeparator';E={$_.NumberFormat.PercentDecimalSeparator}} | FT -A
}

function Get-LocaleDecSep
{
	<#
	.Synopsis
   Displays a subset of Cultures that have the specified decimal separator
	.Example
	Shows locales with period (default) as the decimal separator
	Get-LocaleDecSep
	.EXAMPLE
	Shows locales with comma (,) as the decimal separator
   Get-LocaleDecSep -Separator ,
	#>
	[CmdletBinding()]
    param
    (
		[string]$Separator="."
	)
	Get-NeutralLocales | Where-Object {$_.NumberFormat.PercentDecimalSeparator -match "\$Separator"} | Sort-Object Name | `
	  Select Name, @{N='DecimalSeparator';E={$_.NumberFormat.PercentDecimalSeparator}} | FT -A
}

function Run-NUnit
{
	<#
	.Synopsis
    Runs the NUnit-console.exe against a test dll. You can also specify the locale
	to be set on the emulator and the test-categories to be included in the run.
	Categores are specified as per NUnit doc: http://www.nunit.org/index.php?p=consoleCommandLine&r=2.5.1
	If you don't specify the Categories, all the tests are executed.
	.EXAMPLE
	This sets the locale to DE (German) & runs the tests in Categories ToDo & DE
    Run-Nunit -Locale DE -Categories ToDo+DE -NUnitPath C:\Training\NUnitConsole\nunit-console.exe'
	-TestDllPath .\UITest.dll
	#>
	[CmdletBinding()]
    param
    (
		[Parameter(Mandatory=$false)]
		[string]$avd="emulator-5554",
		[Parameter(Mandatory=$false)]
		[ValidateSet("EN", "DE", "JP", "IR", "RU")]
		[string]$Locale="EN",
		[Parameter(Mandatory=$false)]
		[string]$NUnitPath="nunit-console",
		[Parameter(Mandatory=$true)]
		[string]$TestDllPath,
		[Parameter(Mandatory=$false)]
		[string]$Categories=[String]::Empty
	)
	if( (-not (Test-Path $NUnitPath)) -or (-not (Test-Path $TestDllPath))) {
		[pscustomobject] @{
			Results = "Invalid path for Nunit or Test Dll!"
			DidRun=$false
		}
		return
	}
	#Set locale
	Set-EmuLocale $avd $Locale | Out-Null
	#Run NUnit-console.exe
	$args = @("$TestDllPath")
	if($Categories.Length -gt 0) {
		$args += "/include:$Categories"
	}
	$nunitOutput = Start-Process $NUnitPath -ArgumentList $args -NoNewWindow -Wait -RedirectStandardOutput ./TestResults.txt -PassThru
	<# The console runner now uses negative return codes for errors encountered in trying
	to run the test. Failures or errors in the test themselves give a positive return code (>=0)
	equal to the number of such failures or errors.#>
	Write-Debug $nunitOutput.ExitCode
	if($nunitOutput.ExitCode -GE 0) {
		$doc =(Get-Content .\TestResult.xml)
		$xmlDoc = [xml]$doc
		[pscustomobject] @{
			DidRun=$true
			Locale=$Locale
			Total=$xmlDoc.'test-results'.total
			Errors=$xmlDoc.'test-results'.errors
			Failures=$xmlDoc.'test-results'.failures
			Date=$xmlDoc.'test-results'.date
			Time=$xmlDoc.'test-results'.time
			Results=$doc
		}
	} else {
		[pscustomobject] @{
			DidRun=$false
			Results=(Get-Content ./TestResults.txt -EA SilentlyContinue)
		}
	}
}

function Start-UIAutomator
{
	<#
	.Synopsis
   Starts the UIAutomatorViewer delivered with Android SDK tools.
   This tools lets you view the UI components visible on a virtual device.
	#>
	Start-Process uiautomatorviewer -NoNewWindow
}


#Exports
Export-ModuleMember -Function *
