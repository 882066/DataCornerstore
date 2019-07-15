<#todo: 

Dire need for tool to ensure no invalid characters show up in metadata - while MySql can handle it, 
Powershell has to use many replacement operations to be able to work with them and the File System interprets them in its own way
- modify illegal folder names by character replacement
- folder name letter replacement rules like ß=ss - probably best to also exchange umlauts for their two-letter counterparts
- option to set or correct incomplete attributes
- shortening of long paths created by long attributes

enable support for multiple selections in rules

handle duplicate files & file comparions (mainly incoming files)

strange case of files being in DB with dates but without any other data 
//seems to be a specific problem with 4 files - all four of them were defective and couldn't be read as files of their type

Still problems with high commata in deletion 


#Limitations that were not removed as they didn't hamper the tests:
Errors if paths are longer than 250 characters



#The Script cannot handle:

Different version of windows and ensuing different localization options - solution: update array $usedAttributes manually

Requirements:
- Permission to run Powershell Scripts
- .Net-Framework
- Powershell 6 Core or higher
- MySQL .Net connector installed
- MySql server and permissions to access it, create, drop and use tables - Enter your settings into $connectionString
- Permissions to access an availiable Drive c:\ - If not, change in $com at $Hashmap in the config-part of this Script
- Permissions to access your Source and Target URLs with r/w operations - otherwise define them in locations you have access to ($source, $target)
#>

#functions------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

<#
    retrieve function - requires $query to be in SQL-valid syntax

    returns Dataset Object
#>
function retrieve([String]$query,[String] $table){
    $command = New-Object MySql.Data.MySqlClient.MySqlCommand($query, $Global:DBcon);
    $dataAdapter = New-Object MySql.Data.MySqlClient.MySqlDataAdapter($command);
    $dataset = New-Object System.Data.DataSet;
    [void]$dataAdapter.Fill($dataset,$table); 
    return $dataset;
}


<#
    delete function - requires $query to be in SQL-valid syntax
#>
function delete([String]$query, [String] $table){
    $command = New-Object MySql.Data.MySqlClient.MySqlCommand($query, $Global:DBcon);
    [void]$command.ExecuteNonQuery();
}

<#
    function to find structural patterns in existing file structures
    uses path and the values from $attributelist

    returns an array with an arraylist containing file metadata (path & the contents of $attributelist) in pos[0] 
    and the attribute-parsed paths of these in pos[2] devided by '*'s
#>
function patternRecognition([String]$table){
    $pathfinder = New-Object System.Collections.ArrayList;
    $query = "select path";
    for($i = 0; $i -lt $attributeList.length; $i++){
        $query = $query + " , " + $attributeList[$i];
    }
    $query = $query +" from "+$table +" where path IS NOT NULL" ;
    $data = retrieve $query $table;
    foreach($entry in $data.Tables[$table]){
        #$entry;
        [void]$pathfinder.add($entry);
    }
    $trailblazer = New-Object System.Collections.ArrayList;
    $foundcounter = 0;
    # $pathfinder now contains all paths and sorting data not equal NULL from table file
    for($i = 0; $i -lt $pathfinder.Count; $i++){
        $pathToGlory = Split-Path -LiteralPath $pathfinder[$i][0];
        $checkme= (Get-Item -LiteralPath $pathToGlory).Name;
        $stepsToRoot = ($pathToGlory.ToCharArray() | Where-Object {$_ -eq '\'} | Measure-Object).Count;
        $pattern = New-Object 'String[]' $stepsToRoot;
        $takenAttribute = New-Object System.Collections.ArrayList;
        for ($m = $stepsToRoot-1; $m -ge 0; $m--){
            $foundcounter = 0;
            for($k =0; $k -lt $attributeList.Length; $k++){
                #Write-Host $checkme " matched to " ($pathfinder[$i][($k+1)] -replace (":"," -")) -ForegroundColor Red
                if($pathfinder[$i][($k+1)] -ne [System.DBNull]::Value){
                #assuming the folder name is always equal or shorter than the metaattribute 
                if(($pathfinder[$i][($k+1)] -replace(":"," -")-replace ("\[","-") -replace("\]","-") -replace ("\(","-") -replace ("\)","-")) -match ($checkme -replace ("\[","-")-replace("\]","-")-replace ("\(","-") -replace ("\)","-"))) 
                {
                    #check if attribute is not already used
                    if($pattern -notcontains ("*"+$attributeList[$k])){
                    $pattern[$m]="*"+$attributeList[$k];
                    $foundcounter = $foundcounter+1;
                    }
                }
                }}
             #if no match occured, check for matches with attribute names
             if($pattern[$m].Length -lt 1){
                for($k =0; $k -lt $attributeList.Length; $k++){
                    if($checkme -match $attributeList[$k]){
                    $pattern[$m] = "*"+$attributeList[$k];}
                    }
            # if still no match has been found use folder name instead of attribute name
                if($pattern[$m].Length -lt 1){
                    $pattern[$m] = $checkme;}
                }
            # if $foundcounter indicates more than one match when matched against attribute values, set to multiple
            if($foundcounter -gt 1)
                {
                    $pattern[$m] = "*multiple";
                }
            $pathToGlory = Split-Path -LiteralPath $pathToGlory;
            if ($pathToGlory.Length -gt 0){
                $checkme =(Get-Item -LiteralPath $pathToGlory).Name;
            }
        }
        [void]$trailblazer.Add($pattern);
    }
    For($qwertz = 0; $qwertz -lt $pathfinder.Count; $qwertz++){
        #Write-Host $pathfinder[$qwertz]['path'] -ForegroundColor Yellow;
        #Write-Host $trailblazer[$qwertz] -ForegroundColor Cyan;
    }
    return @($pathfinder, $trailblazer);
}


<#
function to start measuring for a single item
#>
function startTest{
$Global:time = Get-Date;
$Global:CPU = (get-Process -id $PID).cpu ;
$Global:RAM = (get-Process -id $PID).WS;
}

<#
function to end measuring for a single item
#>
function stopTest{
    $newTime = Get-Date;
    $cpuCheck = (get-process -Id $PID).cpu;
    $ramCheck = (Get-Process -id $PID).WS;
    $Global:RAM = ($Global:RAM + $ramCheck)/2/1MB;
    $deltaTime = (New-TimeSpan -start $time -End $newTime).TotalSeconds;
    $percent = [int](($cpuCheck - $cpu)/($numberLogicalProc*$deltaTime) * 100)
    $query = "Insert into measurement (starttime, endtime, percentageCPU, RAMinMB, deltatimeinseconds) VALUES ('"+$time+"' ,'"+$newTime+"' ,"+$percent+","+$Global:RAM+","+$deltaTime+")";
    Write-Host $query -ForegroundColor Cyan
    $command = New-Object MySql.Data.MySqlClient.MySqlCommand($query, $DBcon);
    [void]$command.ExecuteNonQuery();
}

<#
function to start measuring for a whole run
#>
function startMeasure{
    $query = "select count(sequenceNumber) as result from Measurement;"
    $data = retrieve $query 'measurement'
    $Global:startIndex = ($data.Tables['measurement'].Rows[0][0])+1;
    $Global:startTime = Get-Date;
}

<#
function to end measuring for a whole run
#>
function endMeasure([String] $moduleName){
    $endTime = Get-Date;
    $query = "select count(sequenceNumber) as result from Measurement;"
    $data = retrieve $query 'measurement';
    $endIndex = $data.Tables['measurement'].Rows[0][0];
    $deltaTime = (New-TimeSpan -start $startTime -End $endTime).TotalSeconds;
    $query= "INSERT INTO measurementIndex (startsAt , endsAt , startTime , endTime , secondsduration, numberLogicalProcessors , amountMaxRAM , clusterAlgorithm)VALUES ("+$Global:startIndex+","+$endIndex+",'"+$Global:startTime+"','"+$endTime+"',"+$deltatime + ","+ $numberLogicalProc+","+$amountRAM+",'"+$moduleName+"')";
    Write-Host $query -ForegroundColor Yellow;
    $command = New-Object MySql.Data.MySqlClient.MySqlCommand($query, $DBcon);
    [void]$command.ExecuteNonQuery();

}


<#
function to read metaData from File
original author: Thomas Malkewitz @dotps1
heavily modified by: Boris Neeb
source: https://www.powershellgallery.com/packages/Get-ItemExtendedAttribute 
parameter : String containing full path name
#>
function extractMetadata ([String[]] $Path, [String]$table){

$shell = New-Object -ComObject Shell.Application;

foreach ($pathValue in $Path) {
        if($measure){startTest;}
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
        
            for($key = 0; $key -lt $usedAttributes.Length;$key++){
                    $trueKey = ""+$usedAttributes[$key];
                    $value = $shellParent.GetDetailsOf(
                    $shellLeaf, $trueKey
                );
                #Write-Host $trueKey " is key to " $value " at " $metaData[$trueKey]
                #escape characters so SQL represents them correctly
                $value = $value -replace("\\","\\");
                $value = $value -replace("\'","\'");
                $value = $value -replace("\t","\t");
                $value = $value -replace("\n","\n");
                $value = $value -replace("\r","\r");
                $value = $value.Trim();

                if($key -eq 0){
                $meta = $meta +"'"+ $value+"'";
                $meta2 = $meta2 + "" + $metaData[$trueKey] +"";
                }
                else
                {
                $meta2 = $meta2 + ", " + $metaData[$trueKey] +"";
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
             #Write-Host "meta = " $meta
             #Write-Host "meta2 = " $meta2
             if($measure){stopTest;}
        }
        $meta2 = $meta2 + ")";
        $meta = $meta2 + $meta +")";
        #Write-Host $meta -ForegroundColor green;
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
function applyRules([String] $table){
    $partOfPath ='';
    foreach($rule in $ruleset)
    {
        $query = "select * from "+$table+" where "+ $rule[0];
        $data = retrieve $query $table
        foreach($entry in $data.Tables[$table])
        {
            $name = $target+$rule[1];#+$partOfPath;
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
            if($move){
                Move-Item -LiteralPath $helpmate -Destination ($name);}
            else{
                Copy-Item -LiteralPath $helpmate -Destination ($name);}
        }
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
        }
    }
}


<#
function to create a ruleset using files from table file
restrictions on values to be considered will be made in config section

todo - abfangen wenn alle Ergebnisse der ersten queryreihe 0 sind

Param: requires attribute list to sort by
$attributeList = @('fileType','artist','album','itemType', 'extensionType');
#>
function subSpaceCluster([String[]] $list, [String[]] $table, [String[]] $and){
    $hashList = @{};
    Write-Host "Entering the function";
    Write-Host $list.Length;
    Write-Host $list;
    $stored = New-Object 'String[]' 1;
    #if several attributes are to be considered
    if($list.Length -gt 1){
    #get amount of entries in table for each attribute
    for ($counter = 0; $counter -lt $list.Length; $counter++){
    $query = "select count(" + $list[$counter] + ") as result from "+$table +" " + $and +";"
    Write-Host $query;
    $data = retieve $query $table;
    $hashList.Add($list[$counter], $data.Tables[$table].Rows[0][0]);
    }
    #$forward is sign to continue - false if all values in $hashList are zero
    $forward = $false;
    foreach($item in $hashList.Keys){
        if ($hashList.$item -as[int] -lt 1){
        #remove attributes without instances from $list
        $list = $list | Where-Object { $_ -ne $item};
        }
        if ($hashList.$item -as[int] -gt 0){
        $forward = $true;
        }}
    Write-Host ($hashList | Out-String) -ForegroundColor Red;
    Write-Host $forward -ForegroundColor Magenta;
    if($forward){
    $max = 0;
    #find attribute with most entries  
    foreach($item in $hashList.Keys){
        if($hashList.$item -gt $max){
        $max = $hashList.$item;
        $stored[0] = $item;
        }}
    $maxcounter = 0;
    #check how many attributes have maximum density / most entries
    foreach($item in $hashList.Keys){
        if($hashList.$item -eq $max){
        $maxcounter++;
        }}
    #if more than one attribute has maximum density / most entries
    if($maxcounter -gt 1){
    $storedTwo = New-Object 'String[]' $maxcounter;
    $count = 0;
    #get identifiers of those attributes
    foreach($item in $hashList.Keys){
        if($hashList.$item -eq $max){
        $storedTwo[$count]=$item;
        $count++;
        }}
    Write-Host ($storedTwo | Out-String) -ForegroundColor Green;
    $secondHashList = @{};
    #get amount of distinct values for each attribute with max density
    for ($counter = 0; $counter -lt $storedTwo.Length; $counter++){
    $query = "select count(DISTINCT " + $storedTwo[$counter] + ") as result from "+$table +" " + $and +";"
    Write-Host $query;
    $data = retrieve $query $table
    $secondHashList.Add($list[$counter], $data.Tables[$table].Rows[0][0]);
    $secondHashList;
    }}
    $maxDistinct = [int]::MAXVALUE;
    #find attribute with least distinct entries, if multiple have the same, choose first one (arbitrary choice as anyone will do)
    foreach($item in $secondHashList.Keys){
        if(($secondHashList.$item -lt $maxDistinct) -AND ($secondHashList.$item -gt 0)){
        $maxDistinct = $hashList.$item;
        $stored[0] = $item;
        }
    }}
    if($forward -eq $false){
    $stored[0] = '';
    }}
    #in case $list only contains one entry
    Write-Host "Entering Output code" -ForegroundColor Blue;
    Write-Host "chosen attribute is "$stored[0] -ForegroundColor Blue;
    #Start Backend - recurse if other attributes are available
    if ($list.Length -eq 1){
    $stored = $list;
    }
    #new list omitting chosen attribute
    $newList = $list | Where-Object { $_ -ne $stored[0]};
    Write-Host "Chosen attribute is " $stored[0];
    $retMap = [ordered]@{};
    #if there will be a next level to be considered step
    if($newList.Length -gt 0){
    #if chosen value is of a type that can only take on a very limited range of predetermined values, recurse for each of those in table
    If($metaDataFileType -contains $stored[0])
    {
    $query = "select DISTINCT " + $stored[0] + " from "+$table + " " + $and +";"
    Write-Host $query;
    $data = retrieve $query $table;
    Write-Host $data.Tables[$table].Rows.Count;
    Write-Host "Stored value = " $stored[0];
    for ($i=0;$i -lt $dataset.Tables[$table].Rows.Count;$i++){
        if(($dataset.Tables[$table].Rows[$i][0] -ne [System.DBNull]::Value) -and ($dataset.Tables[$table].Rows[$i][0] -ne '0') -and ($dataset.Tables[$table].Rows[$i][0] -ne $NULL)){
        Write-Host $dataset.Tables[$table].Rows[$i][0];
        $newKey = $dataset.Tables[$table].Rows[$i][0];
        Write-Host "Rows of table output here";
        $statement = $stored[0] + "='" + $newKey +"'";
        Write-Host $statement;
        $where = $add;
        if($add.length -lt 1){
                $where = "WHERE "+$statement;
            }
            else{
                $where = $where + " AND "+$statement;
            }
        Write-Host $where;
        $addMe = subSpaceCluster $newList $table $where;
        Write-Host ($addMe | Out-String) -ForegroundColor DarkMagenta;
        $helpmate = "";
        foreach($entry in $addMe.Keys){
        $helpmate = $helpmate +" " + $entry + " : " + $addMe[$entry] + ";"
        }
        Write-Host $helpmate -ForegroundColor DarkRed;
        $retMap.add($statement, $helpmate );
        }}


    foreach($set in $dataset[$table]){
    $value=$set[$stored[0]];
    Write-Host "Value is" $value;
    Write-Host "value should display here";
    }


    }
    #if chosen value is of a type that can take on a multitude of values 
    else{
        #Write-Host "another round we go";

        $statement = $stored[0] + "";
        #Write-Host $statement;
        $where = $add;
        if($add.length -lt 1){
                $where = "WHERE "+$statement + " IS NOT NULL ";
            }
            else{
                $where = $where + " AND "+$statement;
            }
        #Write-Host $where;
        $addMe = subSpaceCluster $newList $table $where;
        #Write-Host ($addMe | Out-String) -ForegroundColor DarkMagenta;
        $helpmate = "";
        foreach($entry in $addMe.Keys){
        $helpmate = $helpmate +" " + $entry + " : " + $addMe[$entry] + ""
        }
        #Write-Host $helpmate -ForegroundColor DarkRed;
        $retMap.add($statement, $helpmate );
        





    if (($stored[0] -ne [System.DBNull]::Value) -and ($stored[0] -ne $Null)){
    $retMap.add($stored[0], '');}
    else{
    $retMap.add('', '');
    }
    }
    }
    else{
    $retMap.add($stored[0],'');
    }
    return $retMap;
    }















# Configuration part of script----------------------------------------------------------------------------------------------------------------------------------------------------------------
# Source URL
# Where should the script check files
$source = "F:\Music";
# Target URL
# Where should the script deliver files to in an ordered fashion
$target = "F:\";
# DB connection details
# Everything needed to connect to database goes in here
$connectionString = "server=localhost;port=3306;uid=administrator;database=clusterofclusters;pwd=admin;charset=utf8mb4";


#Measurement mode
$measure = $false;
if($measure){
#Number of logical Processors
$numberLogicalProc = Get-WmiObject win32_processor |Measure-Object -Property NumberOfLogicalProcessors -sum |% {[math]::Round($_.sum)};
#Amount of RAM availiable to the System in MB
$amountRAM = Get-WmiObject CIM_PhysicalMemory | Measure-Object -Property capacity -sum | % {[math]::round(($_.sum / 1MB),2)}
#initializing of variables for measuring purposes
$startTime = get-date;
$time = get-date;
$RAM = $null;
$CPU =  $null;
$startIndex = $null;
startTest;
}


#attributes used to reduce the complete $metaData to usable size. 
#The complete list of named attributes in the English localozation is at the very end of this Script
$usedAttributes = [int32[]]@(1,2,3,4,5,9,10,11,12,13,14,15,16,19,20,21,24,26,27,28,30,31,42,104,133,160,164,165,166,174,175,176,177,178,194,196,199,210,213,239,242,243,248,249,255,279);

#Hashmap for Metadata aquisition - create dynamically from System using $usedAttributes
# HashMap for metadata
$metaData = [ordered]@{};
$com = (New-Object -ComObject Shell.Application).NameSpace('C:\');
for($index = 1; $index -lt 400; $index++){
$helpmate = $com.GetDetailsOf($com,$index)-replace (' ','');
$helpmate = $helpmate -replace ("/","");
$helpmate = $helpmate -replace ("\.","");
$helpmate = $helpmate -replace ("\\","");
$helpmate = $helpmate -replace ("\-","");
$helpmate = $helpmate -replace("'",'');
#evading SQL keywords
$helpmate = $helpmate -replace("#",'TrackNumber');
if($usedAttributes.Contains($index)){
$ind = ""+$index;
$metaData.Add($ind,$helpmate);
}}
#remove all empty values
($metaData.GetEnumerator() | ? { -not $_.Value }) | % { $metaData.Remove($_.Name) }


<#
array of attributes that should be sorted by their values instead of their type 
consists of attributes with limited amount of values
#>
$metaDataFileType = @("Perceivedtype","Kind","itemType", "Genre");

#array of attributes to be considered for sorting files
$attributeList = @('Perceivedtype','Contributingartists','Album', 'Year');

#basic ruleset for testing purposes
#format for single rules: [attribute] or [attribute = specific value] followed by an optional *[foldername] in case the foldername is not derived from an attribute
#example: "fileType = 'Audio' *Music"
$ruleset = @(
@("Perceivedtype = 'Audio'","music",'Contributingartists','Album'),
@("Perceivedtype = 'Unspecified'","documents",'itemType'),
@("Perceivedtype = 'Video'", "video",'Title')
);





#List of implemented sorting modules
$sortingModules = @(,"applyRules");

#List of implemented pattern recognition modules
$pathAnalyzerModules = @(,"pathAnalyzer");

#List of implemented clustering-algorithms
$clusterModules = @(,"subSpaceCluster");

#DBscan attributes
$minParts = 1; $maxDistance = 4; $functionOfDistance = $null;

#Setting of atomic-binary choices
#Automatic mode will check DB, target and source location in this order to find a ruleset to apply
$automaticMode = $false;
#Overwrite duplicates in target location - will currently only check file name
$overwrite = $true;
#testing if location is availiable
$checkPhysicalAvailability = $false;
#Pack target so that a minimum amount of free space remains
$packToFit = $false;
#If Archiving = true: move file to target, else backup and just copy
$move = $true;
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





#Bootstrapping part of Script-----------------------------------------------------------------------------------------------------------------------------------------------------------
#code partially abducted from: https://vwiki.co.uk/MySQL_and_PowerShell

#connect to DB
[void][System.Reflection.Assembly]::LoadWithPartialName("MySql.Data");
$DBcon = new-Object MySql.Data.MySqlClient.MySqlConnection;
$DBcon.ConnectionString = $connectionString;
[void]$DBcon.Open();

#create string used for creation of tables "file" and "fileIndex" with correct fields
$query = "(";
for($i = 0; $i -le $usedAttributes.length; $i++)
{
   if($i -lt $usedAttributes.length-1){
   $var = "VARCHAR(30)"
   if(($usedAttributes[$i] -eq 21) -or ($usedAttributes[$i] -eq 194) -or ($usedAttributes[$i] -eq 13) -or ($usedAttributes[$i] -eq 20)-or ($usedAttributes[$i] -eq 14)){
    $var = "VARCHAR(255)";
    }
   $query = $query + "" + $metaData[""+$usedAttributes[$i]] + " " + $var +","
   #Write-Host " query + " $metaData[""+$usedAttributes[$i]]  "with running counter at" $i " and $usedAttributes.length at " $usedAttributes.length;
   }
   elseif($i -lt $usedAttributes.length){
   $query = $query + "" + $metaData[""+$usedAttributes[$i]] + " VARCHAR(30)"
   #Write-Host " query + " $metaData[""+$usedAttributes[$i]]  "with running counter at" $i " and $usedAttributes.length at " $usedAttributes.length;
   }
}

$query = $query + ") CHARACTER SET=utf8mb4";
#ensure tables 'file' and 'fileIndex' exist
$queryHelp = "CREATE TABLE IF NOT EXISTS file"+$query;
#Write-Host $query;
#Create table 'file' if it does not exist
$command = New-Object MySql.Data.MySqlClient.MySqlCommand($queryHelp, $DBcon);
[void]$command.ExecuteNonQuery();
#Create table 'fileIndex' if it does not exist
$queryHelp = "CREATE TABLE IF NOT EXISTS fileIndex"+$query;
$command = New-Object MySql.Data.MySqlClient.MySqlCommand($queryHelp, $DBcon);
[void]$command.ExecuteNonQuery();
#Create table 'Measurement' if it does not exist
$queryHelp = "CREATE TABLE IF NOT EXISTS Measurement (sequenceNumber int NOT NULL AUTO_INCREMENT, starttime varchar(60), endtime varchar(60), percentageCPU varchar(60), RAMinMB varchar(60), deltatimeinseconds varchar(60), PRIMARY KEY(sequenceNumber))";
$command = New-Object MySql.Data.MySqlClient.MySqlCommand($queryHelp, $DBcon);
[void]$command.ExecuteNonQuery();
#Create table 'MeasurementIndex' if it does not exist
$queryHelp = "CREATE TABLE IF NOT EXISTS MeasurementIndex (sequenceNumber int NOT NULL AUTO_INCREMENT, startsAt int, endsAt int, startTime varchar(60), endTime varchar(60), secondsduration double , numberLogicalProcessors varchar(30), amountMaxRAM varchar(30), clusterAlgorithm varchar(30), PRIMARY KEY(sequenceNumber))";
$command = New-Object MySql.Data.MySqlClient.MySqlCommand($queryHelp, $DBcon);
[void]$command.ExecuteNonQuery();


<#
   Main part of the script ----------------------------------------------------------------------------------------------------------------------------------------------------------------------
#>
if($measure){
    $query = "select count(sequenceNumber) as result from Measurement;"
    $data = retrieve $query 'measurement'
    $Global:startIndex = ($data.Tables['measurement'].Rows[0][0])+1;
    stopTest;
    endMeasure("Script ready");
    startMeasure;
    startTest;
    sleep 5;
    stopTest;
    endMeasure("five second sleep");
    startMeasure;
}

#get all files in source directory and extract their metadata into DB

#$handle = get-Childitem -File -LiteralPath $source -Recurse| Select-Object -ExpandProperty FullName;
#foreach($path in $handle)
#{
#extractMetadata $path 'file';
#}

if($measure){
endMeasure("extractMetadata");
}

if($ruleset.Length -lt 1)
{
  $newRules =subSpaceCluster $attributeList 'file' '';
  $newRules;
}


$foldersByAttribute = patternRecognition 'file'


#applyRules 'file';



#Cleanup part of Script ----------------------------------------------------------------------------------------------------
#$queryHelp = "DROP TABLE file";
#$command = New-Object MySql.Data.MySqlClient.MySqlCommand($queryHelp, $DBcon);
#[void]$command.ExecuteNonQuery();

#$DBcon.Close();







<#
Appendix

File Metadata as indexed in Microsoft 10 Professional with system localization set to English

Name                           Value                                                                                                                                     
----                           -----                                                                                                                                     
1                              Size                                                                                                                                      
2                              Item type                                                                                                                                 
3                              Date modified                                                                                                                             
4                              Date created                                                                                                                              
5                              Date accessed                                                                                                                             
6                              Attributes                                                                                                                                
7                              Offline status                                                                                                                            
8                              Availability                                                                                                                              
9                              Perceived type                                                                                                                            
10                             Owner                                                                                                                                     
11                             Kind                                                                                                                                      
12                             Date taken                                                                                                                                
13                             Contributing artists                                                                                                                      
14                             Album                                                                                                                                     
15                             Year                                                                                                                                      
16                             Genre                                                                                                                                     
17                             Conductors                                                                                                                                
18                             Tags                                                                                                                                      
19                             Rating                                                                                                                                    
20                             Authors                                                                                                                                   
21                             Title                                                                                                                                     
22                             Subject                                                                                                                                   
23                             Categories                                                                                                                                
24                             Comments                                                                                                                                  
25                             Copyright                                                                                                                                 
26                             #                                                                                                                                         
27                             Length                                                                                                                                    
28                             Bit rate                                                                                                                                  
29                             Protected                                                                                                                                 
30                             Camera model                                                                                                                              
31                             Dimensions                                                                                                                                
32                             Camera maker                                                                                                                              
33                             Company                                                                                                                                   
34                             File description                                                                                                                          
35                             Masters keywords                                                                                                                          
36                             Masters keywords                                                                                                                          
37                                                                                                                                                                       
38                                                                                                                                                                       
39                                                                                                                                                                       
40                                                                                                                                                                       
41                                                                                                                                                                       
42                             Program name                                                                                                                              
43                             Duration                                                                                                                                  
44                             Is online                                                                                                                                 
45                             Is recurring                                                                                                                              
46                             Location                                                                                                                                  
47                             Optional attendee addresses                                                                                                               
48                             Optional attendees                                                                                                                        
49                             Organizer address                                                                                                                         
50                             Organizer name                                                                                                                            
51                             Reminder time                                                                                                                             
52                             Required attendee addresses                                                                                                               
53                             Required attendees                                                                                                                        
54                             Resources                                                                                                                                 
55                             Meeting status                                                                                                                            
56                             Free/busy status                                                                                                                          
57                             Total size                                                                                                                                
58                             Account name                                                                                                                              
59                                                                                                                                                                       
60                             Task status                                                                                                                               
61                             Computer                                                                                                                                  
62                             Anniversary                                                                                                                               
63                             Assistant's name                                                                                                                          
64                             Assistant's phone                                                                                                                         
65                             Birthday                                                                                                                                  
66                             Business address                                                                                                                          
67                             Business city                                                                                                                             
68                             Business country/region                                                                                                                   
69                             Business P.O. box                                                                                                                         
70                             Business postal code                                                                                                                      
71                             Business state or province                                                                                                                
72                             Business street                                                                                                                           
73                             Business fax                                                                                                                              
74                             Business home page                                                                                                                        
75                             Business phone                                                                                                                            
76                             Callback number                                                                                                                           
77                             Car phone                                                                                                                                 
78                             Children                                                                                                                                  
79                             Company main phone                                                                                                                        
80                             Department                                                                                                                                
81                             E-mail address                                                                                                                            
82                             E-mail2                                                                                                                                   
83                             E-mail3                                                                                                                                   
84                             E-mail list                                                                                                                               
85                             E-mail display name                                                                                                                       
86                             File as                                                                                                                                   
87                             First name                                                                                                                                
88                             Full name                                                                                                                                 
89                             Gender                                                                                                                                    
90                             Given name                                                                                                                                
91                             Hobbies                                                                                                                                   
92                             Home address                                                                                                                              
93                             Home city                                                                                                                                 
94                             Home country/region                                                                                                                       
95                             Home P.O. box                                                                                                                             
96                             Home postal code                                                                                                                          
97                             Home state or province                                                                                                                    
98                             Home street                                                                                                                               
99                             Home fax                                                                                                                                  
100                            Home phone                                                                                                                                
101                            IM addresses                                                                                                                              
102                            Initials                                                                                                                                  
103                            Job title                                                                                                                                 
104                            Label                                                                                                                                     
105                            Last name                                                                                                                                 
106                            Mailing address                                                                                                                           
107                            Middle name                                                                                                                               
108                            Cell phone                                                                                                                                
109                            Nickname                                                                                                                                  
110                            Office location                                                                                                                           
111                            Other address                                                                                                                             
112                            Other city                                                                                                                                
113                            Other country/region                                                                                                                      
114                            Other P.O. box                                                                                                                            
115                            Other postal code                                                                                                                         
116                            Other state or province                                                                                                                   
117                            Other street                                                                                                                              
118                            Pager                                                                                                                                     
119                            Personal title                                                                                                                            
120                            City                                                                                                                                      
121                            Country/region                                                                                                                            
122                            P.O. box                                                                                                                                  
123                            Postal code                                                                                                                               
124                            State or province                                                                                                                         
125                            Street                                                                                                                                    
126                            Primary e-mail                                                                                                                            
127                            Primary phone                                                                                                                             
128                            Profession                                                                                                                                
129                            Spouse/Partner                                                                                                                            
130                            Suffix                                                                                                                                    
131                            TTY/TTD phone                                                                                                                             
132                            Telex                                                                                                                                     
133                            Webpage                                                                                                                                   
134                            Content status                                                                                                                            
135                            Content type                                                                                                                              
136                            Date acquired                                                                                                                             
137                            Date archived                                                                                                                             
138                            Date completed                                                                                                                            
139                            Device category                                                                                                                           
140                            Connected                                                                                                                                 
141                            Discovery method                                                                                                                          
142                            Friendly name                                                                                                                             
143                            Local computer                                                                                                                            
144                            Manufacturer                                                                                                                              
145                            Model                                                                                                                                     
146                            Paired                                                                                                                                    
147                            Classification                                                                                                                            
148                            Status                                                                                                                                    
149                            Status                                                                                                                                    
150                            Client ID                                                                                                                                 
151                            Contributors                                                                                                                              
152                            Content created                                                                                                                           
153                            Last printed                                                                                                                              
154                            Date last saved                                                                                                                           
155                            Division                                                                                                                                  
156                            Document ID                                                                                                                               
157                            Pages                                                                                                                                     
158                            Slides                                                                                                                                    
159                            Total editing time                                                                                                                        
160                            Word count                                                                                                                                
161                            Due date                                                                                                                                  
162                            End date                                                                                                                                  
163                            File count                                                                                                                                
164                            File extension                                                                                                                            
165                            Filename                                                                                                                                  
166                            File version                                                                                                                              
167                            Flag color                                                                                                                                
168                            Flag status                                                                                                                               
169                            Space free                                                                                                                                
170                                                                                                                                                                      
171                                                                                                                                                                      
172                            Group                                                                                                                                     
173                            Sharing type                                                                                                                              
174                            Bit depth                                                                                                                                 
175                            Horizontal resolution                                                                                                                     
176                            Width                                                                                                                                     
177                            Vertical resolution                                                                                                                       
178                            Height                                                                                                                                    
179                            Importance                                                                                                                                
180                            Is attachment                                                                                                                             
181                            Is deleted                                                                                                                                
182                            Encryption status                                                                                                                         
183                            Has flag                                                                                                                                  
184                            Is completed                                                                                                                              
185                            Incomplete                                                                                                                                
186                            Read status                                                                                                                               
187                            Shared                                                                                                                                    
188                            Creators                                                                                                                                  
189                            Date                                                                                                                                      
190                            Folder name                                                                                                                               
191                            Folder path                                                                                                                               
192                            Folder                                                                                                                                    
193                            Participants                                                                                                                              
194                            Path                                                                                                                                      
195                            By location                                                                                                                               
196                            Type                                                                                                                                      
197                            Contact names                                                                                                                             
198                            Entry type                                                                                                                                
199                            Language                                                                                                                                  
200                            Date visited                                                                                                                              
201                            Description                                                                                                                               
202                            Link status                                                                                                                               
203                            Link target                                                                                                                               
204                            URL                                                                                                                                       
205                                                                                                                                                                      
206                                                                                                                                                                      
207                                                                                                                                                                      
208                            Media created                                                                                                                             
209                            Date released                                                                                                                             
210                            Encoded by                                                                                                                                
211                            Episode number                                                                                                                            
212                            Producers                                                                                                                                 
213                            Publisher                                                                                                                                 
214                            Season number                                                                                                                             
215                            Subtitle                                                                                                                                  
216                            User web URL                                                                                                                              
217                            Writers                                                                                                                                   
218                                                                                                                                                                      
219                            Attachments                                                                                                                               
220                            Bcc addresses                                                                                                                             
221                            Bcc                                                                                                                                       
222                            Cc addresses                                                                                                                              
223                            Cc                                                                                                                                        
224                            Conversation ID                                                                                                                           
225                            Date received                                                                                                                             
226                            Date sent                                                                                                                                 
227                            From addresses                                                                                                                            
228                            From                                                                                                                                      
229                            Has attachments                                                                                                                           
230                            Sender address                                                                                                                            
231                            Sender name                                                                                                                               
232                            Store                                                                                                                                     
233                            To addresses                                                                                                                              
234                            To do title                                                                                                                               
235                            To                                                                                                                                        
236                            Mileage                                                                                                                                   
237                            Album artist                                                                                                                              
238                            Sort album artist                                                                                                                         
239                            Album ID                                                                                                                                  
240                            Sort album                                                                                                                                
241                            Sort contributing artists                                                                                                                 
242                            Beats-per-minute                                                                                                                          
243                            Composers                                                                                                                                 
244                            Sort composer                                                                                                                             
245                            Disc                                                                                                                                      
246                            Initial key                                                                                                                               
247                            Part of a compilation                                                                                                                     
248                            Mood                                                                                                                                      
249                            Part of set                                                                                                                               
250                            Period                                                                                                                                    
251                            Color                                                                                                                                     
252                            Parental rating                                                                                                                           
253                            Parental rating reason                                                                                                                    
254                            Space used                                                                                                                                
255                            EXIF version                                                                                                                              
256                            Event                                                                                                                                     
257                            Exposure bias                                                                                                                             
258                            Exposure program                                                                                                                          
259                            Exposure time                                                                                                                             
260                            F-stop                                                                                                                                    
261                            Flash mode                                                                                                                                
262                            Focal length                                                                                                                              
263                            35mm focal length                                                                                                                         
264                            ISO speed                                                                                                                                 
265                            Lens maker                                                                                                                                
266                            Lens model                                                                                                                                
267                            Light source                                                                                                                              
268                            Max aperture                                                                                                                              
269                            Metering mode                                                                                                                             
270                            Orientation                                                                                                                               
271                            People                                                                                                                                    
272                            Program mode                                                                                                                              
273                            Saturation                                                                                                                                
274                            Subject distance                                                                                                                          
275                            White balance                                                                                                                             
276                            Priority                                                                                                                                  
277                            Project                                                                                                                                   
278                            Channel number                                                                                                                            
279                            Episode name                                                                                                                              
280                            Closed captioning                                                                                                                         
281                            Rerun                                                                                                                                     
282                            SAP                                                                                                                                       
283                            Broadcast date                                                                                                                            
284                            Program description                                                                                                                       
285                            Recording time                                                                                                                            
286                            Station call sign                                                                                                                         
287                            Station name                                                                                                                              
288                            Summary                                                                                                                                   
289                            Snippets                                                                                                                                  
290                            Auto summary                                                                                                                              
291                            Relevance                                                                                                                                 
292                            File ownership                                                                                                                            
293                            Sensitivity                                                                                                                               
294                            Shared with                                                                                                                               
295                            Sharing status                                                                                                                            
296                                                                                                                                                                      
297                            Product name                                                                                                                              
298                            Product version                                                                                                                           
299                            Support link                                                                                                                              
300                            Source                                                                                                                                    
301                            Start date                                                                                                                                
302                            Sharing                                                                                                                                   
303                            Availability status                                                                                                                       
304                            Status                                                                                                                                    
305                            Billing information                                                                                                                       
306                            Complete                                                                                                                                  
307                            Task owner                                                                                                                                
308                            Sort title                                                                                                                                
309                            Total file size                                                                                                                           
310                            Legal trademarks                                                                                                                          
311                            Video compression                                                                                                                         
312                            Directors                                                                                                                                 
313                            Data rate                                                                                                                                 
314                            Frame height                                                                                                                              
315                            Frame rate                                                                                                                                
316                            Frame width                                                                                                                               
317                            Spherical                                                                                                                                 
318                            Stereo                                                                                                                                    
319                            Video orientation                                                                                                                         
320                            Total bitrate      

#>