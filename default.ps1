$script:project_config = "Debug"
properties {
	$project_name = "TopGames"
	if(-not $version)
	{
		$version = "1.0.0.0"
	}
	$framework = '4.5'
	$base_dir = resolve-path .
	$build_dir = "$base_dir\_build"
	$temp_package_dir = "$build_dir\temp_for_packaging"
	$package_dir = "$build_dir\latestVersion"
	$topgames_package_file = "$package_dir\TopGames_Package.zip"
	$source_dir = "$base_dir\src"
	$test_dir = "$build_dir\test"
	$result_dir = "$build_dir\results"

	$test_assembly_patterns_unit = @("*.Tests.dll")
	$integration_test_assembly_patterns_unit = @("*IntegrationTests.dll")

	$cassini_exe = 'C:\Program Files (x86)\Common Files\Microsoft Shared\DevServer\10.0\WebDev.WebServer40.EXE'
	$admin_port = 8081
	$topgames_web_dir = "$source_dir\TopGames.UI" 
	$topgames_nsb_dir = "$source_dir\TopGames.Server\bin" 

	$cassini_process_name = "WebDev.WebServer40"

	$db_server = ".\SqlExpress"

	$db_name = "TopGames"
	$db_scripts_dir = "$source_dir\Database\TopGames"

	$all_database_info = @(
		@{"$db_name"="$db_scripts_dir";}
	 )

	$roundhouse_dir = "$base_dir\lib\roundhouse"
	$roundhouse_output_dir = "$roundhouse_dir\output"
	$roundhouse_exe_path = "$roundhouse_dir\rh.exe"
	$roundhouse_cmd_timeout = 300
}

#These are aliases for other build tasks. They typically are named after the camelcase letters (rad = Rebuild All Databases)
#aliases should be all lowercase, conventionally
#please list all aliases in the help task
task default -depends InitialPrivateBuild, WarnSlowBuild
task dev -depends DeveloperBuild
task ci -depends IntegrationBuild
task uad -depends UpdateAllDatabases
task uatd -depends UpdateAllTestDatabases
task rad -depends RebuildAllDatabases
task ratd -depends RebuildAllTestDatabases, UpdateAllTestDatabases
task unit -depends RunAllUnitTests
task udds -depends UpdateDeveloperDatabaseScripts
task snap -depends SnapshotDeveloperDatabase

task help {
	Write-Help-Header
	Write-Help-Section-Header "Comprehensive Building"
	Write-Help-For-Alias "(default)" "Intended for first build or when you want a fresh, clean local copy"
	Write-Help-For-Alias "dev" "Optimized for local dev; Most noteably UPDATES databases instead of REBUILDING"
	Write-Help-For-Alias "ci" "Continuous Integration build (long and thorough) with packaging"
	Write-Help-Section-Header "Database Maintenance"
	Write-Help-For-Alias "rad" "Rebuild All Databases"
	Write-Help-For-Alias "uad" "Update All Databases"
	Write-Help-For-Alias "ratd" "Rebuild All Test Databases"
	Write-Help-For-Alias "uatd" "Update All Test Databases"
	Write-Help-Footer
	exit 0
}

#These are the actual build tasks. They should be Pascal case by convention
task InitialPrivateBuild -depends StopSystem, Clean, RunAllUnitTests

task DeveloperBuild -depends StopSystem, Clean, CommonAssemblyInfo, Compile, UpdateAllDatabases, RunAllUnitTests

task IntegrationBuild -depends SetReleaseBuild, StopSystem, Clean, CommonAssemblyInfo, Compile, RunAllUnitTests, PackageTopGames

task ReleaseBuild -depends SetReleaseBuild, Clean, CommonAssemblyInfo, Compile, PackageTopGames

task BuildAndStart -depends StopSystem, Clean, CommonAssemblyInfo, RebuildAllDatabases, UpdateAllDatabases, Compile, StartSystem

task SetReleaseBuild {
	$script:project_config = "Release"
}

task RebuildAllDatabases {
	foreach ($db in $all_database_info) {
		$db.GetEnumerator() | %{ deploy-database "Rebuild" $db_server $_.Key $_.Value}
	}
}

task UpdateAllDatabases {
	foreach ($db in $all_database_info) {
		$db.GetEnumerator() | %{ deploy-database "Update" $db_server $_.Key $_.Value}
	}
}

task RebuildAllTestDatabases {
	foreach ($db in $all_database_info) {
		$db.GetEnumerator() | %{deploy-database "Rebuild" $db_server ($_.Key + "_Test") $_.Value}
	}
}

task UpdateAllTestDatabases {
	foreach ($db in $all_database_info) {
		$db.GetEnumerator() | %{deploy-database "Update" $db_server ($_.Key + "_Test") $_.Value}
	}
}

task CommonAssemblyInfo {
	create-commonAssemblyInfo "$version" $project_name "$source_dir\CommonAssemblyInfo.cs"
}

task CopyAssembliesForTest -Depends Compile {
	copy_all_assemblies_for_test $test_dir
}

task RunAllUnitTests -Depends CopyAssembliesForTest {  
	$test_assembly_patterns_unit | %{ run_tests $_ }
	#$integration_test_assembly_patterns_unit | %{ run_tests $_ }
}

task Compile -depends Clean { 
	exec { msbuild.exe /t:build /v:q /p:Configuration=$project_config /nologo $source_dir\$project_name.sln }
}

task Clean {
	delete_file $topgames_package_file
	delete_directory $temp_package_dir
	delete_directory $build_dir
	create_directory $test_dir 
	create_directory $result_dir
		
	set-location $source_dir
#	get-childitem * -include *.dll -recurse | remove-item
#	get-childitem * -include *.pdb -recurse | remove-item
#	get-childitem * -include *.exe -recurse | remove-item
#	set-location $base_dir
	
	exec { msbuild /t:clean /v:q /p:Configuration=$project_config $source_dir\$project_name.sln }
}

task PackageTopGames -depends SetReleaseBuild, Clean, CommonAssemblyInfo, Compile {
	delete_directory $temp_package_dir
	delete_file $topgames_package_file
	
	#databases
	copy_files "$source_dir\database" "$temp_package_dir\database"
	
	#websites
	copy_website_files "$topgames_web_dir" "$temp_package_dir\web\TopGames"

	#nservicebus
	copy_files "$topgames_nsb_dir\$project_config" "$temp_package_dir\nsb\TopGames"

	#tools
	copy_files "$roundhouse_dir" "$temp_package_dir\tools\roundhouse"
	delete_directory "$temp_package_dir\tools\roundhouse\output"
	
	#pstrami deployment
	copy_files "$base_dir\deployment\TopGames" "$temp_package_dir"
	copy_files "$base_dir\deployment\modules" "$temp_package_dir\modules"

	zip_directory $temp_package_dir $topgames_package_file
}

task StartSystem {
	start-cassini
}

task StopSystem {
	stop-cassini
}

task StartUi {
	stop-cassini
	start-cassini
}

task WarnSlowBuild {
	Write-Host ""
	Write-Host "Warning: " -foregroundcolor Yellow -nonewline;
	Write-Host "The default build you just ran is primarily intended for initial "
	Write-Host "environment setup. While developing you most likely want the quicker dev"
	Write-Host "build task. For a full list of common build tasks, run: "
	Write-Host " > build.bat help"
}

# -------------------------------------------------------------------------------------------------------------
# generalized functions for Help Section
# --------------------------------------------------------------------------------------------------------------

function Write-Help-Header($description) {
	Write-Host ""
	Write-Host "********************************" -foregroundcolor DarkGreen -nonewline;
	Write-Host " HELP " -foregroundcolor Green  -nonewline; 
	Write-Host "********************************"  -foregroundcolor DarkGreen
	Write-Host ""
	Write-Host "This build script has the following common build " -nonewline;
	Write-Host "task " -foregroundcolor Green -nonewline;
	Write-Host "aliases set up:"
}

function Write-Help-Footer($description) {
	Write-Host ""
	Write-Host " For a complete list of build tasks, view default.ps1."
	Write-Host ""
	Write-Host "**********************************************************************" -foregroundcolor DarkGreen
}

function Write-Help-Section-Header($description) {
	Write-Host ""
	Write-Host " $description" -foregroundcolor DarkGreen
}

function Write-Help-For-Alias($alias,$description) {
	Write-Host "  > " -nonewline;
	Write-Host "$alias" -foregroundcolor Green -nonewline; 
	Write-Host " = " -nonewline; 
	Write-Host "$description"
}

# -------------------------------------------------------------------------------------------------------------
# generalized functions 
# --------------------------------------------------------------------------------------------------------------
function deploy-database($action,$server,$db_name,$scripts_dir) {
	$roundhouse_version_file = "$source_dir\TopGames.Core\bin\$project_config\TopGames.Core.dll"

	if ($action -eq "Update"){
		exec { &$roundhouse_exe_path -s $server -d $db_name -f $scripts_dir -vf $roundhouse_version_file --silent -o $roundhouse_output_dir --ct $roundhouse_cmd_timeout }
	}
	if ($action -eq "Rebuild"){
		exec { &$roundhouse_exe_path -s $server -d $db_name -vf $roundhouse_version_file --silent -drop -o $roundhouse_output_dir --ct $roundhouse_cmd_timeout}
		exec { &$roundhouse_exe_path -s $server -d $db_name -f $scripts_dir -vf $roundhouse_version_file --silent --simple -o $roundhouse_output_dir --ct $roundhouse_cmd_timeout }
	}
}

function start-cassini {
	&$cassini_exe "/port:$admin_port" "/path:$topgames_web_dir"
}

function stop-cassini {
	Get-Process | ?{ $_.Name -eq $cassini_process_name } | %{ Stop-Process -Id $_.Id }
}

function run_tests([string]$pattern) {
	
	$items = Get-ChildItem -Path $test_dir $pattern
	$items | %{ run_nunit $_.Name }
}

function global:zip_directory($directory,$file) {
	write-host "Zipping folder: " $directory
	delete_file $file
	cd $directory
	& "$base_dir\lib\7zip\7za.exe" a -mx=9 -r $file | Out-Null
	cd $base_dir
}

function global:delete_file($file) {
	if($file) { remove-item $file -force -ErrorAction SilentlyContinue | out-null } 
}

function global:delete_directory($directory_name) {
  rd $directory_name -recurse -force  -ErrorAction SilentlyContinue | out-null
}

function global:create_directory($directory_name) {
  mkdir $directory_name  -ErrorAction SilentlyContinue  | out-null
}

function global:run_nunit ($test_assembly) {
	$assembly_to_test = $test_dir + "\" + $test_assembly
	$results_output = $result_dir + "\" + $test_assembly + ".xml"
	write-host "Running NUnit Tests in: " $test_assembly
	exec { & $base_dir\lib\nunit\nunit-console-x86.exe $assembly_to_test /nologo /nodots /xml=$results_output /exclude=DataLoader}
}

function global:load_test_data ($test_assembly) {
	$assembly_to_test = $test_dir + "\" + $test_assembly
	write-host "Running DataLoader NUnit Tests in: " $test_assembly
	exec { & lib\nunit\nunit-console-x86.exe $assembly_to_test /nologo /nodots /include=DataLoader}
}

function global:Copy_and_flatten ($source,$include,$dest) {
	ls $source -include $include -r | cp -dest $dest
}

function global:copy_all_assemblies_for_test($destination){
	$bin_dir_match_pattern = "$source_dir\*\bin\$project_config"
	create_directory $destination
	Copy_and_flatten $bin_dir_match_pattern *.exe $destination
	Copy_and_flatten $bin_dir_match_pattern *.dll $destination
	Copy_and_flatten $bin_dir_match_pattern *.config $destination
	Copy_and_flatten $bin_dir_match_pattern *.pdb $destination
	Copy_and_flatten $bin_dir_match_pattern *.sql $destination
	Copy_and_flatten $bin_dir_match_pattern *.xlsx $destination
}

function global:copy_website_files($source,$destination){
	$exclude = @('*.user','*.dtd','*.tt','*.cs','*.csproj') 
	copy_files $source $destination $exclude
	delete_directory "$destination\obj"
}

function global:copy_files($source,$destination,$exclude=@()){    
	create_directory $destination
	Get-ChildItem $source -Recurse -Exclude $exclude | Copy-Item -Destination {Join-Path $destination $_.FullName.Substring($source.length)} 
}

function global:Convert-WithXslt($originalXmlFilePath, $xslFilePath, $outputFilePath) {
   ## Simplistic error handling
   $xslFilePath = resolve-path $xslFilePath
   if( -not (test-path $xslFilePath) ) { throw "Can't find the XSL file" } 
   $originalXmlFilePath = resolve-path $originalXmlFilePath
   if( -not (test-path $originalXmlFilePath) ) { throw "Can't find the XML file" } 
   #$outputFilePath = resolve-path $outputFilePath -ErrorAction SilentlyContinue 
   if( -not (test-path (split-path $originalXmlFilePath)) ) { throw "Can't find the output folder" } 

   ## Get an XSL Transform object (try for the new .Net 3.5 version first)
   $EAP = $ErrorActionPreference
   $ErrorActionPreference = "SilentlyContinue"
   $script:xslt = new-object system.xml.xsl.xslcompiledtransform
   trap [System.Management.Automation.PSArgumentException] 
   {  # no 3.5, use the slower 2.0 one
	  $ErrorActionPreference = $EAP
	  $script:xslt = new-object system.xml.xsl.xsltransform
   }
   $ErrorActionPreference = $EAP
   
   ## load xslt file
   $xslt.load( $xslFilePath )
	 
   ## transform 
   $xslt.Transform( $originalXmlFilePath, $outputFilePath )
}

function global:create-commonAssemblyInfo($version,$applicationName,$filename) {
	"using System.Reflection;
using System.Runtime.InteropServices;

//------------------------------------------------------------------------------
// <auto-generated>
//     This code was generated by a tool.
//     Runtime Version:2.0.50727.4927
//
//     Changes to this file may cause incorrect behavior and will be lost if
//     the code is regenerated.
// </auto-generated>
//------------------------------------------------------------------------------

[assembly: ComVisibleAttribute(false)]
[assembly: AssemblyVersionAttribute(""$version"")]
[assembly: AssemblyFileVersionAttribute(""$version"")]
[assembly: AssemblyCopyrightAttribute(""Copyright 2012-2013"")]
[assembly: AssemblyProductAttribute(""$applicationName"")]
[assembly: AssemblyCompanyAttribute("""")]
[assembly: AssemblyConfigurationAttribute(""release"")]
[assembly: AssemblyInformationalVersionAttribute(""$version"")]"  | out-file $filename -encoding "ASCII"    
}


function script:poke-xml($filePath, $xpath, $value, $namespaces = @{}) {
	[xml] $fileXml = Get-Content $filePath
	
	if($namespaces -ne $null -and $namespaces.Count -gt 0) {
		$ns = New-Object Xml.XmlNamespaceManager $fileXml.NameTable
		$namespaces.GetEnumerator() | %{ $ns.AddNamespace($_.Key,$_.Value) }
		$node = $fileXml.SelectSingleNode($xpath,$ns)
	} else {
		$node = $fileXml.SelectSingleNode($xpath)
	}
	
	Assert ($node -ne $null) "could not find node @ $xpath"
		
	if($node.NodeType -eq "Element") {
		$node.InnerText = $value
	} else {
		$node.Value = $value
	}

	$fileXml.Save($filePath) 
}

function usingx {
	param (
		$inputObject = $(throw "The parameter -inputObject is required."),
		[ScriptBlock] $scriptBlock
	)

	if ($inputObject -is [string]) {
		if (Test-Path $inputObject) {
			[void][system.reflection.assembly]::LoadFrom($inputObject)
		} elseif($null -ne (
			  new-object System.Reflection.AssemblyName($inputObject)
			  ).GetPublicKeyToken()) {
			[void][system.reflection.assembly]::Load($inputObject)
		} else {
			[void][system.reflection.assembly]::LoadWithPartialName($inputObject)
		}
	} elseif ($inputObject -is [System.IDisposable] -and $scriptBlock -ne $null) {
		Try {
			&$scriptBlock
		} Finally {
			if ($inputObject -ne $null) {
				$inputObject.Dispose()
			}
			Get-Variable -scope script |
				Where-Object {
					[object]::ReferenceEquals($_.Value.PSBase, $inputObject.PSBase)
				} |
				Foreach-Object {
					Remove-Variable $_.Name -scope script
				}
		}
	} else {
		$inputObject
	}
}