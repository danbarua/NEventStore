properties {
    $base_directory = Resolve-Path .. 
	$publish_directory = "$base_directory\publish-net40"
	$build_directory = "$base_directory\build"
	$src_directory = "$base_directory\src"
	$output_directory = "$base_directory\output"
	$packages_directory = "$src_directory\packages"

	$sln_file = "$src_directory\EventStore.sln"
	$keyfile = "$src_directory/EventStore.snk"
	$target_config = "Release"
	$framework_version = "v4.0"
	$version = "0.0.0.0"

	$xunit_path = "$base_directory\bin\xunit.runners.1.9.1\tools\xunit.console.clr4.exe"
	$ilMergeModule.ilMergePath = "$base_directory\bin\ilmerge-bin\ILMerge.exe"
	$nuget_dir = "$src_directory\.nuget"

	if($runPersistenceTests -eq $null) {
		$runPersistenceTests = $false
	}
}

task default -depends Build

task Build -depends Clean, UpdateVersion, Compile, Test

task UpdateVersion {
	
	$vSplit = $version.Split('.')
	
	if($vSplit.Length -ne 4)
	{
		throw "Version number is invalid. Must be in the form of 0.0.0.0"
	}

	$major = $vSplit[0]
	$minor = $vSplit[1]

	$assemblyFileVersion = $version
	$assemblyVersion = "$major.$minor.0.0"

	$versionAssemblyInfoFile = "$src_directory/proj/VersionAssemblyInfo.cs"
	"using System.Reflection;" > $versionAssemblyInfoFile
	"" >> $versionAssemblyInfoFile
	"[assembly: AssemblyVersion(""$assemblyVersion"")]" >> $versionAssemblyInfoFile
	"[assembly: AssemblyFileVersion(""$assemblyFileVersion"")]" >> $versionAssemblyInfoFile
}

task Compile {
	exec { msbuild /nologo /verbosity:quiet $sln_file /p:Configuration=$target_config /t:Clean }

	exec { msbuild /nologo /verbosity:quiet $sln_file /p:Configuration=$target_config /p:TargetFrameworkVersion=v4.0 }
}

task Test -depends RunUnitTests, RunPersistenceTests, RunSerializationTests

task RunUnitTests {
	write-host "Unit Tests"

	EnsureDirectory $output_directory

	Invoke-XUnit -Path $src_directory\tests -TestSpec '*EventStore.Core.Tests.dll' `
    -SummaryPath $output_directory\unit_tests.xml `
    -XUnitPath $xunit_path
}

task RunPersistenceTests -precondition { $runPersistenceTests } {
	write-host "Persistence Tests"

	EnsureDirectory $output_directory

	Invoke-XUnit -Path $src_directory\tests -TestSpec '*Persistence.*.Tests.dll' `
    -SummaryPath $output_directory\persistence_tests.xml `
    -XUnitPath $xunit_path
}

task RunSerializationTests {
	write-host "Serialization Tests"

	EnsureDirectory $output_directory

	Invoke-XUnit -Path $src_directory\tests -TestSpec '*Serialization.*.Tests.dll' `
    -SummaryPath $output_directory\serialization_tests.xml `
    -XUnitPath $xunit_path
}

task Package -depends Build, PackageEventStore, PackageMongoPersistence, PackageRavenPersistence, PackageJsonSerialization {
	move $output_directory $publish_directory
}

task PackageEventStore -depends Clean, Compile {
	mkdir "$output_directory\bin" | out-null
	Merge-Assemblies -outputFile "$output_directory\bin\EventStore.dll" -exclude "EventStore.*" -keyfile $keyFile -files @(
		"$src_directory\proj\EventStore\bin\$target_config\EventStore.dll", 
		"$src_directory\proj\EventStore.Core\bin\$target_config\EventStore.Core.dll",
		"$src_directory\proj\EventStore.Serialization\bin\$target_config\EventStore.Serialization.dll",
		"$src_directory\proj\EventStore.Persistence.SqlPersistence\bin\$target_config\EventStore.Persistence.SqlPersistence.dll",
		"$src_directory\proj\EventStore.Wireup\bin\$target_config\EventStore.Wireup.dll"
	)
	
	write-host Rereferencing Merged Assembly
	exec { msbuild /nologo /verbosity:quiet $sln_file /p:Configuration=$target_config /t:Clean }
	
	exec { msbuild /nologo /verbosity:quiet $sln_file /p:Configuration=$target_config /p:ILMerged=true /p:TargetFrameworkVersion=v4.0 }
}

task PackageMongoPersistence -depends Clean, Compile,PackageEventStore {
	mkdir $output_directory\plugins\persistence\mongo | out-null

	Merge-Assemblies -outputFile "$output_directory/plugins/persistence/mongo/EventStore.Persistence.MongoPersistence.dll" -exclude "EventStore.*" -keyfile $keyFile -files @(
		"$src_directory/proj/EventStore.Persistence.MongoPersistence/bin/$target_config/EventStore.Persistence.MongoPersistence.dll",
		"$src_directory/proj/EventStore.Persistence.MongoPersistence.Wireup/bin/$target_config/EventStore.Persistence.MongoPersistence.Wireup.dll"
	)

	copy "$src_directory\proj\EventStore.Persistence.MongoPersistence\bin\$target_config\MongoDB*.dll" "$output_directory\plugins\persistence\mongo"
}

task PackageRavenPersistence -depends Clean, Compile, PackageEventStore {
	mkdir $output_directory\plugins\persistence\raven | out-null
	
	Merge-Assemblies -outputFile "$output_directory/plugins/persistence/raven/EventStore.Persistence.RavenPersistence.dll" -exclude "EventStore.*" -keyfile $keyFile -files @(
		"$src_directory/proj/EventStore.Persistence.RavenPersistence/bin/$target_config/EventStore.Persistence.RavenPersistence.dll",
		"$src_directory/proj/EventStore.Persistence.RavenPersistence.Wireup/bin/$target_config/EventStore.Persistence.RavenPersistence.Wireup.dll"
	)

	copy "$src_directory\proj\EventStore.Persistence.RavenPersistence\bin\$target_config\Raven*.dll" "$output_directory\plugins\persistence\raven"
}

task PackageJsonSerialization -depends Clean, Compile, PackageEventStore {
	mkdir $output_directory\plugins\serialization\json-net | out-null

	Merge-Assemblies -outputFile "$output_directory/plugins/serialization/json-net/EventStore.Serialization.Json.dll" -exclude "EventStore.*" -keyfile $keyFile -files @(
		"$src_directory/proj/EventStore.Serialization.Json/bin/$target_config/EventStore.Serialization.Json.dll", 
		"$src_directory/proj/EventStore.Serialization.Json/bin/$target_config/Newtonsoft.Json*.dll",
		"$src_directory/proj/EventStore.Serialization.Json.Wireup/bin/$target_config/EventStore.Serialization.Json.Wireup.dll"
	)
}

task PackageDocs {
	mkdir "$output_directory\doc"
	copy "$base_directory\doc\*.*" "$output_directory\doc"
}

task Clean {
	Clean-Item $publish_directory -ea SilentlyContinue
    Clean-Item $output_directory -ea SilentlyContinue
}

task NuGetPack -depends Package {
	gci -r -i *.nuspec "$nuget_dir" |% { .$nuget_dir\nuget.exe pack $_ -basepath $base_directory -o $publish_directory -version $version }
}

function EnsureDirectory {
	param($directory)

	if(!(test-path $directory))
	{
		mkdir $directory
	}
}