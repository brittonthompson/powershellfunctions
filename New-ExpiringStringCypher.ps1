function New-ExpiringStringCypher {
    <#
    .SYNOPSIS
        Creates a string cypher from a given string using the given cipher key
    .DESCRIPTION
        Using the given string and key the cipher is generated based on the date and current username. So, since the date is only the month and year the cipher changes after the month rolls over. Also, if a different user attempts to generate the same cipher it will be invalid.
        Use the same logic to create and decrypt the generated cipher string.
    .EXAMPLE
        New-ExpiringStringCypher -String 'foobar' -CipherKey 'CD103SK8JMZ+L^G2$A5%({&)TUFYV9_#I-B=4P@QWHX!}O76ERN'
    #>

    param (
        [Parameter(Position = 0, Mandatory = $True)]
        # string to generate the cypher from
        [string]$String,
        # this is the key so it should be randomized and probably stored outside of your code this is an example
        [string]$CipherKey = 'CD103SK8JMZ+L^G2$A5%({&)TUFYV9_#I-B=4P@QWHX!}O76ERN'
    )

    # get the date in the January 2019 format, generate a character array sort in a repeatable manner
    $Date = ((Get-Date -Format y).Replace(" ", "")).ToCharArray() | Sort-Object

    # repait the the process with the current username 
    $User = $env:USERNAME.ToCharArray() | Sort-Object

    # again, repeat the character array and sort for the given string
    $StringArray = $String.ToCharArray() | Sort-Object

    # concatenate the sorted string array, user and date
    $Characters = $StringArray + $User + $Date

    # create a character array from the cipher key
    $CipherArray = $CipherKey.ToCharArray()

    # we don't want the cipher to be short based on the length of the string so we add this many characters
    $CharsToAdd = $CipherArray.Length - $Characters.Count

    # if there's no need to append additional characters we'll negate appending
    if ($CharsToAdd -lt 0) { $CharsToAdd = 0 }

    # establish the array we'll return in the end
    $NewArray = @()

    # establish the array we'll use to store values we're going to append
    $AddArray = @()

    # generate our starting location with the cipher array
    $StartIndex = 0..($CipherArray.Count - 1) | Where-Object { 
        $CipherArray[$_] -eq $CipherArray[$CipherArray.Count - $StringArray.Count]
    }

    # add characters to our array we'll append to short strings
    for ($i = 0; $i -lt $CharsToAdd; $i++) {
        if (($StartIndex - $i) -lt 0) { $S = $StartIndex + $i } else { $S = $StartIndex - $i }
        $AddArray += $CipherArray[$S]
    }

    # reset our counter variable and generate our final array
    $i = 0
    $Characters | ForEach-Object {
        if (($StartIndex - $i) -lt 0) { $S = $StartIndex + $i } else { $S = $StartIndex - $i }
        $NewArray += $CipherArray[$S]
        $i++

        # if we've run out of characters in our string we append from our characters to add array
        if ($i -le $CharsToAdd) { $NewArray += $AddArray[ - $i] }
    }

    # return the cipher
    $Return = -join $NewArray
    $Return
}