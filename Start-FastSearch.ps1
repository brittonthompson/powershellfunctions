function Start-FastSearch {
    <#
    .SYNOPSIS
        Drastically improves finding items within an object over using the where-object filter.
    .DESCRIPTION    
        Uses the C# list search assembly to search a given object field for a specific value.
    .PARAMETER Object
        PowerShell object to search.
    .PARAMETER Field
        The field within the PowerShell object to search.
    .PARAMETER Value
        The value to search for within the field.
    .EXAMPLE
        Start-FastSearch -Object $Obj -Field "Name" -Value "Joe"
    .NOTES
        Original C# from https://chentiangemalc.wordpress.com/2017/06/08/faster-where-object-in-powershell
    #>
    
    [CmdletBinding()]
    param(
        [System.Object]$Object,
        [string]$Field,
        [string]$Value
    )

    $Source = @"
 
using System;
using System.Management.Automation;
using System.Collections.Generic;
    
namespace FastSearch
{
    
    public static class Search
    {
        public static List<Object> Find(PSObject[] collection, string column, string data)
        {
            List<Object> results = new List<Object>();
            foreach(PSObject item in collection)
            {
                if (item.Properties[column].Value.ToString() == data) { results.Add(item); }
            }
    
            return results;
        }
    }
}
"@

    if (-not ([System.Management.Automation.PSTypeName]'FastSearch.Search').Type) {
        Add-Type -ReferencedAssemblies $Assem -TypeDefinition $Source -Language CSharp
    }

    [FastSearch.Search]::Find($Object, $Field, $Value)
}
