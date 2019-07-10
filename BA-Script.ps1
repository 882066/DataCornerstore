<#todo: 
catch complete paths longer than 250
enable support for multiple selections in rules
handle duplicate files & file comparions (mainly incoming files)
modify ruleset path types to incorporate $target
strange case of files being in DB with dates but without any other data
modify illegal folder names by character replacement
folder name letter replacement rules like ss=ß

#cannot handle:

#>

# Configuration part of script
# Source URL
$source = "F:\musik\";
# Target URL
$target = "F:\music\";
# DB connection details
$connectionString = "server=localhost;port=3306;uid=administrator;database=clusterofclusters;pwd=admin;charset=utf8mb4";
#Order of checks for automatic mode - 3 = DB, 2 = target URL, 1 = source URL
$automaticModeOrder = 321;

#DBscan attributes
$minParts = 1; $maxDistance = 4; $functionOfDistance = $null;

#Hashmap for Metadata aquisition - complete with attribute name and format for DB
$metaData = $null;
$metaData = [ordered]@{ 
'1' = @("size","VARCHAR(60)"); 
'2' = @("itemType","VARCHAR(30)"); 
'3' = @("dateModified","VARCHAR(30)"); 
'4' = @("dateCreated","VARCHAR(30)"); 
'5' = @("dateAccessed","VARCHAR(30)"); 
'9' = @("fileType","VARCHAR(30)") ; 
'10' = @("owner","VARCHAR(60)"); 
'11' = @("dataType" ,"VARCHAR(30)"); 
'12' = @("dateTaken","VARCHAR(30)"); 
'13' = @("contributingArtists","VARCHAR(60)"); 
'14' = @("album","VARCHAR(60)"); 
'15' = @("year","VARCHAR(30)"); 
'16' = @("genre","VARCHAR(60)"); 
'19' = @("rating","VARCHAR(30)"); 
'20' = @("artist","VARCHAR(255)"); 
'21' = @("title","VARCHAR(60)"); 
'24' = @("comments","VARCHAR(255)"); 
'26' = @("trackNumber","VARCHAR(30)"); 
'27' = @("length","VARCHAR(30)"); 
'28' = @("bitRate","VARCHAR(30)"); 
'31' = @("dimension","VARCHAR(30)"); 
'32' = @("cameraMaker","VARCHAR(60)"); 
'42' = @("programName","VARCHAR(60)"); 
'164' = @("extensionType","VARCHAR(30)"); 
'165' = @("fileName","VARCHAR(255)"); 
'174' = @("bitDepth","VARCHAR(30)"); 
'175' = @("horizontalResolution","VARCHAR(30)"); 
'176' = @("width","VARCHAR(30)"); 
'177' = @("verticalResolution","VARCHAR(30)"); 
'178' = @("height","VARCHAR(30)"); 
'194' = @("completePath","VARCHAR(255)"); 
'196' = @("itemType2","VARCHAR(30)"); 
'210' = @("encodedBy","VARCHAR(255)"); 
'213' = @("publisher","VARCHAR(30)"); 
'249' = @("partOfSet","VARCHAR(30)"); 
'254' = @("compressionRate","VARCHAR(30)"); 
'255' = @("EXIFversion","VARCHAR(30)"); 
'257' = @("exposureBias","VARCHAR(30)"); 
'259' = @("exposureTime","VARCHAR(30)"); 
'260' = @("FStop","VARCHAR(30)"); 
'261' = @("flash","VARCHAR(30)"); 
'262' = @("focalLength","VARCHAR(30)"); 
'263' = @("35mmFocalLength","VARCHAR(30)"); 
'264' = @("isoSpeed","VARCHAR(30)"); 
'269' = @("meteringMode","VARCHAR(30)"); 
'275' = @("whiteBalance","VARCHAR(30)");
};

#array of attributes to ce considered for sorting files
$attributeList = @('fileType','artist','album', 'year');

#basic ruleset for testing purposes
$ruleset = @(
@("fileType = 'Audio'","F:\music",'artist','album'),
@("fileType = 'Unspecified'","F:\documents",'itemType'),
@("fileType = 'Video'", "F:\video",'title')
);

#Measurement mode
$measure = $false;

<#
#List of implemented sorting modules

applyRules

#List of implemented pattern recognition modules for usage on source URL



#List of implemented pattern recognition modules for usage on target URL



#List of implemented clustering-algorithms
#>

#Setting of atomic-binary choices
#Automatic mode will check DB, target and source location and, depending on the setting, work with the data found to create a new structure in target#Overwrite duplicates at target location
$automaticMode = $false;
#Overwrite duplicates in target location - will currently only check file name
$overwrite = $true;
#testing if location is availiable
$checkPhysicalAvailability = $false;
#Pack target so that a minimum amount of free space remains
$packToFit = $false;
#If Archiving = true: move file to target, else backup and just copy
$archiving = $false;
#considers data in source folder as a self-contained unit
$isSelfcontained = $false;
#Is a space requirement analysis needed?
$spaceAnalysis = $false;
#Query user to make decisions
$queryUser = $false;
#Currently folders in source are considered to be self-contained structures containing dependancies
#Flat pattern recognition ignores these folders
#This is the planned toggle if there will be a check for excecutables or files tagges as likely to have dependencies
$dependenceAlert = $false;


#functions

<#
function to read metaData from File
Author: Thomas Malkewitz @dotps1
stolen and modified by: Boris Neeb
source: https://www.powershellgallery.com/packages/Get-ItemExtendedAttribute 
parameter : String containing full path name
#>
function extractMetadata ([String[]] $Path, [String]$table){

$shell = New-Object -ComObject Shell.Application;

foreach ($pathValue in $Path) {
        $item = Resolve-Path -LiteralPath $pathValue
        $parent = Split-Path -Path $item
        $leaf = Split-Path -Path $item -Leaf 

        $shellParent = $shell.NameSpace(
            $parent
        )

        $shellLeaf = $shellParent.ParseName(
            $leaf
        )
        $meta = "VALUES (";
        $meta2 = "INSERT INTO "+ $table +" (";
        
            foreach ($key in $metaData.Keys) {
                $value = $shellParent.GetDetailsOf(
                    $shellLeaf, $key -as[int]
                )
                #escape characters so SQL represents them correctly
                $value = $value -replace("\\","\\");
                $value = $value -replace("\'","\'");
                $value = $value -replace("\t","\t");
                $value = $value -replace("\n","\n");
                $value = $value -replace("\r","\r");
                $value = $value.Trim();

                if($key -eq '1'){
                $meta = $meta +"'"+ $value+"'";
                $meta2 = $meta2 + "" + $metaData[$key][0] +"";
                }
                else
                {
                $meta2 = $meta2 + ", " + $metaData[$key][0] +"";
                if ($value.Length -gt 0)
                    {
                    $meta = $meta + ", '" + $value +"'"
                    }
                else
                    {
                    $meta = $meta + ", NULL"
                    }
                }
                
             }
        
        }
        $meta2 = $meta2 + ")";
        $meta = $meta2 + $meta +")";
        #$meta;
        $command = New-Object MySql.Data.MySqlClient.MySqlCommand($meta, $DBcon);
        [void]$command.ExecuteNonQuery();
 
        

$null = [System.Runtime.InteropServices.Marshal]::ReleaseComObject(
        $shell
    )
    Remove-Variable -Name shell
}

<#
function to put files from source to target structure
uses $ruleset to decide where each file goes.
standard behaviour is a foldername composition "Unknown" + attribute if attribute value is null
#>
function applyRules{
foreach($rule in $ruleset)
{
$query = "select * from file where "+ $rule[0];
$command = New-Object MySql.Data.MySqlClient.MySqlCommand($query, $DBcon);
$dataAdapter = New-Object MySql.Data.MySqlClient.MySqlDataAdapter($command);
$dataset = New-Object System.Data.DataSet;
[void]$dataAdapter.Fill($dataset,"file"); 
foreach($entry in $dataset.Tables["file"])
{
$name = ""+$rule[1];
for($var = 2;$var -lt $rule.length; $var++) 
{
if($entry[$rule[$var]] -ne [System.DBNull]::Value){
$helpmate = $entry[$rule[$var]] -replace(":"," -");
$helpmate = $helpmate-replace("''","''");
$name = $name +'\'+ $helpmate;
}
else {$name = $name + '\Unknown '+$rule[$var];}
}
$entry['completePath'];
New-Item -ItemType Directory -Force -Path $name;
$helpmate = $entry['completePath'];
Move-Item -LiteralPath $helpmate -Destination ($name);
if($?)
{
$query = "INSERT INTO fileIndex SELECT * FROM file WHERE completePath ='" +($entry['completePath']-replace("'","''")) + "';" ;
$query = $query -replace("\\","\\");
$command = New-Object MySql.Data.MySqlClient.MySqlCommand($query, $DBcon);
[void]$command.ExecuteNonQuery();
$query = "UPDATE fileIndex SET completePath = '" + ($name-replace("'","''")) + "\" + (($entry['fileName']-replace("'","''"))-replace("'","''")) + $entry['extensionType'] +"' WHERE completePath = '"+ ($entry['completePath']-replace("'","''")) +"';";
$query = $query -replace("\\","\\");
$command = New-Object MySql.Data.MySqlClient.MySqlCommand($query, $DBcon);
[void]$command.ExecuteNonQuery();
$query = "DELETE FROM file WHERE completePath = '"+ (($entry['completePath']-replace("'","''"))-replace("'","''")) +"';";
$query = ($query -replace("\\","\\"));
$command = New-Object MySql.Data.MySqlClient.MySqlCommand($query, $DBcon);
[void]$command.ExecuteNonQuery();
}}
}
}

<#
function to create a ruleset using files from table file
restrictions on values to be considered will be made in config section

Param: requires attribute list to sort by
$attributeList = @('fileType','artist','album','itemType', 'extensionType');
#>
function subSpaceCluster([String[]] $list){
    $hashList = @{};
    for ($counter = 0; $counter -lt $list.Length; $counter++){
    $query = "select count( " + $list[$counter] + ") as result from file;"
    $command = New-Object MySql.Data.MySqlClient.MySqlCommand($query, $DBcon);
    $dataAdapter = New-Object MySql.Data.MySqlClient.MySqlDataAdapter($command);
    $dataset = New-Object System.Data.DataSet;
    [void]$dataAdapter.Fill($dataset,"file"); 
    foreach($data in $dataset.Tables['file']){
    #$data;
    $hashList.Add($list[$counter], $data['result']);
    }}
    $max = 0;
    $stored;
    foreach($item in $hashList.Keys){
        if($hashList.$item -gt $max){
        $max = $hashList.$item;
        $stored = $item;
        }
    }
    $newList = $list | Where-Object { $_ -ne $stored};
    
    #return @($stored
}


<#
function to create a ruleset using files from table file
restrictions on values to be considered will be made in config section

Param: requires attribute list to sort by
$attributeList = @('fileType','artist','album','itemType', 'extensionType');

function findPattern([String[]] $list, [String[]]$listUsed )
{
    $storageHash = @{};
    $attList = New-Object 'int[]' $list.Length; 
    for($var = 0; $var -lt $list.Length; $var++) 
    {
        $query = "select distinct " + $list[$var] +" from file; "
        if($listUsed.Length -gt 0){
        for($counter = 0; $counter -lt $listUsed.Length; $counter++){
        if($counter -eq 0){
        $query = $query + " WHERE " + $listUsed[0];
        }
        else{
        $query = $query + " AND " + $listUsed[$counter];
        }}}
        $command = New-Object MySql.Data.MySqlClient.MySqlCommand($query, $DBcon);
        $dataAdapter = New-Object MySql.Data.MySqlClient.MySqlDataAdapter($command);
        $dataset = New-Object System.Data.DataSet;
        [void]$dataAdapter.Fill($dataset,"file"); 
        $instancesOfValues = [System.Collections.ArrayList]::new();
        foreach($entry in $dataset.Tables["file"]) 
        {
            if ($entry[$list[$var]] -ne [System.DBNull]::Value)
            {
                $attList[$var]++;
                [void]$instancesOfValues.Add($entry[$list[$var]]);
            }
        }
        $storageHash.Add($list[$var],$instancesOfValues);
    }
    $dummy = [int]($attList | measure -Minimum).Minimum;
    $newList = $list | Where-Object { $_ -ne $list[$attlist.IndexOf($dummy)]};
    $placeholder = $list[$attList.IndexOf($dummy)];     
    #foreach($item in $storageHash.$placeholder){
    #$helper = $placeholder +" = '" + $item + "'";
    #$helper;
    #$usedList =@($helper;)
    findPatternHelper $storageHash;
    #}

    $ret = @{};
}

function findPatternHelper([Hashtable] $Hash ){
    $attList = {}; 
    foreach($key in $Hash.Keys){
        $counter = 0;
        foreach($value in $key){
        $query = "select " + $list[$var] +" from file;"
        $query;
        $command = New-Object MySql.Data.MySqlClient.MySqlCommand($query, $DBcon);
        $dataAdapter = New-Object MySql.Data.MySqlClient.MySqlDataAdapter($command);
        $dataset = New-Object System.Data.DataSet;
        [void]$dataAdapter.Fill($dataset,"file"); 
        $instancesOfValues = [System.Collections.ArrayList]::new();
        foreach($entry in $dataset.Tables["file"]) 
        {
            if ($entry[$list[$var]] -ne [System.DBNull]::Value)
            {
                $attList[$var]++;
                [void]$instancesOfValues.Add($entry[$list[$var]]);
            }
        }
        
    
    
    }
    }
    {
        $query = "select " + $list[$var] +" from file; "
        if($listUsed.Length -gt 0){
        for($counter = 0; $counter -lt $listUsed.Length; $counter++){
        if($counter -eq 0){
        $query = $query + " WHERE " + $listUsed[0];
        }
        else{
        $query = $query + " AND " + $listUsed[$counter];
        }}}
        $command = New-Object MySql.Data.MySqlClient.MySqlCommand($query, $DBcon);
        $dataAdapter = New-Object MySql.Data.MySqlClient.MySqlDataAdapter($command);
        $dataset = New-Object System.Data.DataSet;
        [void]$dataAdapter.Fill($dataset,"file"); 
        $instancesOfValues = [System.Collections.ArrayList]::new();
        foreach($entry in $dataset.Tables["file"]) 
        {
            if ($entry[$list[$var]] -ne [System.DBNull]::Value)
            {
                $attList[$var]++;
                [void]$instancesOfValues.Add($entry[$list[$var]]);
            }
        }
        $storageHash.Add($list[$var],$instancesOfValues);
    }
    $dummy = [int]($attList | measure -Minimum).Minimum;
    $newList = $list | Where-Object { $_ -ne $list[$attlist.IndexOf($dummy)]};
    $placeholder = $list[$attList.IndexOf($dummy)];     
    $storageHash;
    #foreach($item in $storageHash.$placeholder){
    #$helper = $placeholder +" = '" + $item + "'";
    #$helper;
    #$usedList =@($helper;)
    #findPattern $newList $usedList;
    #}

    $ret = @{};

}
#>

#Bootstrapping part of Script
#code partially abducted from: https://vwiki.co.uk/MySQL_and_PowerShell

[void][System.Reflection.Assembly]::LoadWithPartialName("MySql.Data");
$DBcon = new-Object MySql.Data.MySqlClient.MySqlConnection;
$DBcon.ConnectionString = $connectionString;
[void]$DBcon.Open();


#create tables "file" and "fileIndex" with correct fields if they do not exist
$query = "(";
foreach($key in $metaData.Keys)
{
   
   $query = $query + "" + $metaData[$key][0] +" " + $metaData[$key][1] + ",";
   
}
$query = $query.Remove($query.Length-1);
$query = $query + ") CHARACTER SET=utf8mb4";

$queryHelp = "CREATE TABLE IF NOT EXISTS file"+$query;
$command = New-Object MySql.Data.MySqlClient.MySqlCommand($queryHelp, $DBcon);
[void]$command.ExecuteNonQuery();
$queryHelp = "CREATE TABLE IF NOT EXISTS fileIndex"+$query;
$command = New-Object MySql.Data.MySqlClient.MySqlCommand($queryHelp, $DBcon);
[void]$command.ExecuteNonQuery();

#get all files in source directory and extract their metadata into DB
#$handle = get-Childitem -File -LiteralPath $source -Recurse | Select-Object -ExpandProperty FullName;
#foreach($path in $handle)
#{
#extractMetadata $path 'file';
#}

if($ruleset.Length -lt 1)
{

  subSpaceCluster $attributeList;
}

applyRules;





#Cleanup part of Script
#$queryHelp = "DROP TABLE file";
#$command = New-Object MySql.Data.MySqlClient.MySqlCommand($queryHelp, $DBcon);
#[void]$command.ExecuteNonQuery();

#$DBcon.Close();