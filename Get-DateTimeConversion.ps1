function Get-DateTimeConversion {
    <#
    .SYNOPSIS
        Converts or gives the current datetime with various values for the date and time
    .DESCRIPTION
        Created to quickly generate responses for the workday, weekend and 7x24 schedules.
    .EXAMPLE
        Get-DateTimeConversion
    .EXAMPLE
        Get-DateTimeConversion "11/12/1982 6:35 AM"
    .EXAMPLE
        Get-DateTimeConversion -Date (get-date) -AfterHoursStart 20 -AfterHoursEnd 6
    #>

    [CmdletBinding()]
    param (
        [parameter(Mandatory = 0, Position = 0, ValueFromPipeline = 1, ValueFromPipelineByPropertyName = 1)]
        [datetime]$Date = (Get-Date),
        [parameter(Mandatory = 0, Position = 1)]
        [int]$AfterHoursStart = 18,
        [parameter(Mandatory = 0, Position = 2)]
        [int]$AfterHoursEnd = 7
    )

    [PSCustomObject]@{
        DateID           = $(Get-Date $Date -Format yyyyMMdd)
        Date             = $(Get-Date $Date -Format "yyyy-MM-dd hh:mm:ss")
        DateFull         = $(Get-Date $Date -Format F)
        DateDayOfWeek    = $($Date.DayOfWeek)
        DateDayOfWeekNum = $($Date.Day)
        DateDayOfYear    = $($Date.DayOfYear)
        DateWeekOfYear   = $((Get-Date $Date -UFormat %V))
        DateMonth        = $((Get-Date $Date -UFormat %B))
        DateMonthNum     = $($Date.Month)
        DateYear         = $($Date.Year)
        DateQuarter      = $(
            switch ([int]$Date.Month) {
                { $_ -ge 1 -and $_ -le 3 } { 1 }
                { $_ -ge 4 -and $_ -le 6 } { 2 }
                { $_ -ge 7 -and $_ -le 9 } { 3 }
                { $_ -ge 10 -and $_ -le 12 } { 4 }
            }
        )
        DateWeekday      = $(
            switch ($Date.DayOfWeek) {
                "Sunday" { $false }
                "Monday" { $true }
                "Tuesday" { $true }
                "Wednesday" { $true }
                "Thursday" { $true }
                "Friday" { $true }
                "Saturday" { $false }
            }
        )
        TimeID           = $(Get-Date $Date -Format hhmm)
        Time             = $(Get-Date $Date -Format h:mm:ss)
        TimeHour         = $($Date.Hour)
        TimeMinute       = $($Date.Minute)
        Time9to5         = $($Date.Hour -ge 9 -or $Date.Hour -lt 17)
        Time7x24         = $($Date.Hour -lt $AfterHoursEnd -or $Date.Hour -ge $AfterHoursStart)
        TimeQuarter      = $(Get-Date ($Date.AddMinutes(- $Date.Minute % 15)) -Format hh:mm)
        TimeStamp        = $(Get-Date $Date -Format o)
        TimeEpoch        = $(Get-Date $Date -UFormat %s)
    }
}
